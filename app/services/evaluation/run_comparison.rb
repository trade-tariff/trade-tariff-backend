module Evaluation
  # Spike: compares evaluation runs side by side (quality, latency, cost per 1,000
  # guided searches), e.g. the same question_model on OpenAI and on Bedrock.
  #
  # - Quality (top-1/top-5) and latency use results without an error.
  # - Cost uses every result, because an errored search still spends tokens.
  class RunComparison
    Row = Data.define(
      :run_id,
      :question_model,
      :provider,
      :results,
      :errors,
      :top1_pct,
      :top5_pct,
      :p50_latency_seconds,
      :p95_latency_seconds,
      :mean_provider_calls,
      :cost_per_1000_usd,
      :cost_per_1000_with_gb_uplift_usd,
    )

    # OpenAI charges a 10% uplift on regional processing endpoints (we call
    # gb.api.openai.com) for models released on or after 5 March 2026.
    # AiUsage::PricingCalculator uses global list prices, so it leaves this out.
    # https://developers.openai.com/api/docs/pricing
    GB_UPLIFT = 1.1
    GB_UPLIFT_MODELS = %w[
      gpt-5.4
      gpt-5.4-mini
      gpt-5.4-nano
      gpt-5.5
      gpt-5.6
      gpt-5.6-sol
      gpt-5.6-terra
      gpt-5.6-luna
      gpt-6-astra
    ].freeze

    STATS_SQL = <<~SQL.squish.freeze
      count(*) AS results,
      count(error) AS errors,
      avg(CASE WHEN error IS NULL THEN gold_in_top1::int END) AS top1,
      avg(CASE WHEN error IS NULL THEN gold_in_top5::int END) AS top5,
      percentile_cont(0.5) WITHIN GROUP (ORDER BY CASE WHEN error IS NULL THEN latency_seconds END) AS p50,
      percentile_cont(0.95) WITHIN GROUP (ORDER BY CASE WHEN error IS NULL THEN latency_seconds END) AS p95,
      avg(provider_calls) AS provider_calls,
      avg(cost_usd) AS cost
    SQL

    def self.call(run_ids)
      new(run_ids).call
    end

    def initialize(run_ids)
      @run_ids = Array(run_ids).map { |id| Integer(id) }
    end

    def call
      runs = EvaluationRun.where(id: @run_ids).all.index_by(&:id)
      missing = @run_ids - runs.keys
      raise ArgumentError, "Unknown evaluation run ids: #{missing.join(', ')}" if missing.any?

      @run_ids.map { |id| row_for(runs.fetch(id)) }
    end

  private

    def row_for(run)
      stats = EvaluationResult.where(run_id: run.id).select(Sequel.lit(STATS_SQL)).naked.first
      model = run.question_model.to_s
      bedrock = BedrockOpenaiClient.bedrock_model?(model)
      cost_per_1000 = per_1000(stats[:cost])

      Row.new(
        run_id: run.id,
        question_model: model,
        provider: bedrock ? 'Bedrock' : 'OpenAI',
        results: stats[:results],
        errors: stats[:errors],
        top1_pct: percentage(stats[:top1]),
        top5_pct: percentage(stats[:top5]),
        p50_latency_seconds: rounded(stats[:p50], 2),
        p95_latency_seconds: rounded(stats[:p95], 2),
        mean_provider_calls: rounded(stats[:provider_calls], 2),
        cost_per_1000_usd: cost_per_1000,
        cost_per_1000_with_gb_uplift_usd: gb_uplift?(model, bedrock) ? rounded(cost_per_1000 * GB_UPLIFT, 2) : cost_per_1000,
      )
    end

    def gb_uplift?(model, bedrock)
      !bedrock && GB_UPLIFT_MODELS.include?(model)
    end

    def per_1000(cost)
      rounded(cost && cost * 1000, 2)
    end

    def percentage(ratio)
      rounded(ratio && ratio * 100, 1)
    end

    def rounded(value, digits)
      value&.to_f&.round(digits)
    end
  end
end
