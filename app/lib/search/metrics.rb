# frozen_string_literal: true

module Search
  # Emits low-cardinality search metrics as a raw CloudWatch Embedded Metric
  # Format line. Rails.logger prefixes lines, so this writes to stdout directly.
  # CloudWatch extracts the metrics from that line. A dropped write must not
  # affect the search that produced the event.
  class Metrics
    NAMESPACE = 'TradeTariff/Search'
    MAX_LINE_BYTES = 4096
    REQUEST_SOURCES = %w[frontend admin mcp backend_only].freeze
    SEARCH_TYPES = %w[classic interactive internal evaluation classification].freeze
    GUIDED_SEARCH_TYPES = %w[interactive internal].freeze
    GUIDED_OUTCOMES = %w[answers questions error].freeze
    OPERATIONS = %w[search_query_expansion interactive_search interactive_search_final_answer duplicate_question_validator duplicate_question_retry].freeze
    RESPONSE_TYPES = %w[answers questions duplicate_validation error unknown].freeze
    RETRIEVAL_LEGS = %w[opensearch vector].freeze
    RETRIEVAL_STATUSES = %w[success error].freeze
    EXCLUDED_EXPERIMENT_LABELS = %w[hmrc-users].freeze
    METRIC_NAMES = %w[
      SearchEvents
      SearchDuration
      ResultSelections
      QueryExpansions
      AiApiDuration
      EmptyResults
      ResultCount
      CommodityResultCount
      QueryExpansionDuration
      QueryExpansionTimeouts
      AiApiCalls
      RetrievalDuration
      RetrievalFailures
      RetrievalResultCount
      GuidedSearchErrors
      GuidedSearchDuration
      GuidedSearchOutcomes
      DuplicateValidatorFailOpen
    ].freeze

    class << self
      def subscribe!(output: $stdout)
        unsubscribe!
        # config.x outlives a Zeitwerk reload. A class ivar does not, so to_prepare would subscribe twice.
        subscription_registry.search_metrics_subscriber = ActiveSupport::Notifications.subscribe(/\.search\z/) do |*args|
          record(ActiveSupport::Notifications::Event.new(*args), output:)
        end
      end

      def unsubscribe!
        subscriber = subscription_registry.search_metrics_subscriber
        return unless subscriber

        ActiveSupport::Notifications.unsubscribe(subscriber)
        subscription_registry.search_metrics_subscriber = nil
      end

      def record(event, output: $stdout, environment: TradeTariffBackend.environment, service: TradeTariffBackend.service, now: Time.current)
        payload = payload_for(event, environment:, service:, now:)
        return false unless payload

        line = "#{JSON.generate(payload)}\n"
        return false if line.bytesize > MAX_LINE_BYTES

        output.write_nonblock(line, exception: false) == line.bytesize
      rescue StandardError
        false
      end

    private

      def payload_for(event, environment:, service:, now:)
        return if EXCLUDED_EXPERIMENT_LABELS.include?(event.payload[:experiment].to_s)

        name = event.name.to_s.delete_suffix('.search')
        dimensions = base_dimensions(environment, service)
        metrics = []
        values = {}

        case name
        when 'search_completed'
          add_search_event(event.payload, dimensions, metrics, values, outcome: 'completed')
          add_duration(metrics, values, 'SearchDuration', event.payload[:total_duration_ms])
          add_result_metrics(event.payload, metrics, values)
          add_guided_metrics(event.payload, dimensions, metrics, values, failed: false)
        when 'search_failed'
          add_search_event(event.payload, dimensions, metrics, values, outcome: 'failed')
          add_guided_metrics(event.payload, dimensions, metrics, values, failed: true)
        when 'result_selected'
          metrics << metric('ResultSelections', [%w[Environment Service]])
          values[:ResultSelections] = 1
        when 'query_expanded'
          add_value(metrics, values, 'QueryExpansions', 1)
          add_duration(metrics, values, 'QueryExpansionDuration', event.payload[:duration_ms])
        when 'query_expansion_timed_out'
          add_value(metrics, values, 'QueryExpansionTimeouts', 1)
        when 'api_call_completed'
          dimensions[:Operation] = label(event.payload[:operation], OPERATIONS)
          dimensions[:ResponseType] = label(event.payload[:response_type], RESPONSE_TYPES)
          add_duration(metrics, values, 'AiApiDuration', event.payload[:duration_ms], [%w[Environment Service], %w[Environment Service Operation]])
          add_value(metrics, values, 'AiApiCalls', 1, [%w[Environment Service Operation ResponseType]])
        when 'retrieval_leg_completed'
          add_retrieval_metrics(event.payload, dimensions, metrics, values)
        when 'duplicate_question_guard_checked'
          if event.payload[:suspicious] == true
            fail_open = event.payload[:reason].to_s == 'validator_unparseable' ? 1 : 0
            add_value(metrics, values, 'DuplicateValidatorFailOpen', fail_open)
          end
        else
          return
        end
        return if metrics.empty?

        dimensions.merge(values).merge(emf(metrics, now))
      end

      def add_search_event(payload, dimensions, metrics, values, outcome:)
        dimensions[:RequestSource] = label(payload[:request_source], REQUEST_SOURCES)
        dimensions[:SearchType] = label(payload[:search_type], SEARCH_TYPES)
        dimensions[:Outcome] = outcome
        values[:SearchEvents] = 1
        metrics << metric('SearchEvents', [
          %w[Environment Service RequestSource Outcome],
          %w[Environment Service SearchType Outcome],
          %w[Environment Service Outcome],
        ])
      end

      # One sample per terminal request event, including failures. Do not divide
      # a new error series by older traffic metrics with a different history.
      def add_guided_metrics(payload, dimensions, metrics, values, failed:)
        return unless GUIDED_SEARCH_TYPES.include?(payload[:search_type].to_s)

        outcome = failed ? 'hard_failure' : label(payload[:final_result_type], GUIDED_OUTCOMES)
        dimensions[:GuidedOutcome] = outcome
        add_value(metrics, values, 'GuidedSearchErrors', %w[error hard_failure].include?(outcome) ? 1 : 0)
        add_value(metrics, values, 'GuidedSearchOutcomes', 1, [%w[Environment Service GuidedOutcome]])
        add_duration(metrics, values, 'GuidedSearchDuration', payload[:total_duration_ms]) unless failed
      end

      def add_result_metrics(payload, metrics, values)
        result_count = number(payload[:result_count])
        commodity_count = number(payload[:commodity_result_count])
        if result_count
          values[:ResultCount] = result_count
          metrics << metric('ResultCount', [%w[Environment Service SearchType]])
        end
        if commodity_count
          values[:CommodityResultCount] = commodity_count
          metrics << metric('CommodityResultCount', [%w[Environment Service SearchType]])
        end
        return unless empty_result?(payload)

        values[:EmptyResults] = 1
        metrics << metric('EmptyResults', [%w[Environment Service SearchType]])
      end

      def add_retrieval_metrics(payload, dimensions, metrics, values)
        dimensions[:Leg] = label(payload[:leg], RETRIEVAL_LEGS)
        sets = [%w[Environment Service Leg]]
        add_duration(metrics, values, 'RetrievalDuration', payload[:duration_ms], sets)
        status = payload[:status].to_s
        if RETRIEVAL_STATUSES.include?(status)
          add_value(metrics, values, 'RetrievalFailures', status == 'error' ? 1 : 0, sets)
        end
        count = number(payload[:result_count])
        add_value(metrics, values, 'RetrievalResultCount', count, sets) if status == 'success' && count
      end

      def add_value(metrics, values, name, value, dimensions = [%w[Environment Service]])
        values[name.to_sym] = value
        metrics << metric(name, dimensions)
      end

      def add_duration(metrics, values, name, milliseconds, dimensions = [%w[Environment Service]])
        value = seconds(milliseconds)
        add_value(metrics, values, name, value, dimensions) if value
      end

      # Keep aligned with search_quality_dashboard zero_result_condition.
      # Classic exact matches are not empty commodity results. Missing counts
      # are not treated as zero except the classic fallback below.
      # That fallback applies only when the raw commodity count is nil.
      # A supplied count that number rejects is not absence and is not zero.
      def empty_result?(payload)
        search_type = payload[:search_type].to_s
        result_count = number(payload[:result_count])

        if search_type == 'classic'
          classic_empty_result?(payload, result_count)
        elsif %w[interactive internal].include?(search_type)
          result_count&.zero? == true
        else
          false
        end
      end

      def classic_empty_result?(payload, result_count)
        raw_commodity_count = payload[:commodity_result_count]
        deciding_count = raw_commodity_count.nil? ? result_count : number(raw_commodity_count)
        return false unless deciding_count&.zero?

        raw_commodity_count.nil? || payload[:results_type].to_s != 'exact_search'
      end

      def base_dimensions(environment, service)
        {
          Environment: environment.to_s,
          Service: service.to_s,
        }
      end

      def label(value, allowed)
        text = value.to_s
        return 'unknown' if text.empty?
        return text if allowed.include?(text)

        'other'
      end

      def number(value)
        return unless value.is_a?(Numeric) && value.finite? && value >= 0

        value
      end

      def seconds(milliseconds)
        value = number(milliseconds)
        return unless value

        value / 1000.0
      end

      def metric(name, dimensions)
        {
          Namespace: NAMESPACE,
          Dimensions: dimensions,
          Metrics: [{ Name: name, Unit: name.end_with?('Duration') ? 'Seconds' : 'Count' }],
        }
      end

      def emf(metrics, now)
        {
          _aws: {
            Timestamp: (now.to_f * 1000).to_i,
            CloudWatchMetrics: metrics,
          },
        }
      end

      def subscription_registry
        Rails.application.config.x
      end
    end
  end
end
