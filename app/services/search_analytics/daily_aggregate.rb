# frozen_string_literal: true

module SearchAnalytics
  # Adapts complete daily query results to the existing dashboard payload.
  class DailyAggregate < CloudwatchSnapshotQuery::Aggregate
    def initialize(period:, results:, journeys: nil, cost_keys: nil, query_dates: nil)
      @query_dates = query_dates || {}
      @journeys = journeys || Period::VIEWS.index_with do |view|
        JourneyMetrics.new(rows: results.fetch('search_journeys'), period: period.with(view:))
      end
      @histogram = results.fetch('latency_histogram')
      costs = RequestCosts.new(
        trend_rows: results.fetch('ai_cost_trend'),
        journey_keys: cost_keys || @journeys.fetch(period.view).keys,
      ).call
      selections = %w[classic internal].flat_map do |view|
        results.fetch("#{view}_selection_trend").map { |row| row.merge('selectable_search_type' => view) }
      end
      terms = { 'search_terms' => 'search_term_improvements', 'item_ids' => 'item_id_improvements' }.flat_map do |type, name|
        results.fetch(name).map { |row| row.merge('term_type' => type) }
      end
      volume = results.fetch('volume')
      super(
        period:, volume_rows: buckets_for(volume, period), zero_result_rows: buckets_for(volume, period),
        summary_all_latency_rows: [], summary_view_latency_rows: [], source_all_latency_rows: [], source_view_latency_rows: [],
        ai_cost_summary_rows: [costs.fetch(:summary)], ai_cost_trend_rows: buckets_for(costs.fetch(:trend), period),
        selection_rows: selections, selection_trend_rows: buckets_for(selections, period), improvement_term_rows: terms
      )
    end

    def payload
      payload_for(period.view).merge(
        'journeys' => { 'count' => @journeys.fetch(period.view).count },
        'availability' => {
          'journey_metrics' => query_present?('search_journeys'),
          'request_journeys' => query_present?('search_journeys'),
          'costs_match_view' => query_present?('ai_cost_trend'),
          'range_percentiles' => true,
          'latency_percentiles_approximate' => true,
          'latency_histogram_relative_width' => LatencyHistogram::RELATIVE_WIDTH,
          'latency_percentile_method' => 'histogram_upper_bound',
          'terms_complete' => { 'search_terms' => true, 'item_ids' => true },
        },
      )
    end

  private

    def query_present?(name)
      dates = @query_dates[name]
      dates.nil? || dates.any?
    end

    def journey_collected?(bucket)
      dates = @query_dates['search_journeys']
      return true if dates.nil?

      dates.include?(Time.find_zone!('UTC').parse(bucket).to_date)
    end

    def buckets_for(rows, period)
      rows.map do |row|
        copy = row.dup
        if copy['@timestamp'] && !period.single_day?
          copy['@timestamp'] = Time.find_zone!('UTC').parse(copy['@timestamp']).beginning_of_day.iso8601
        end
        copy
      end
    end

    def summary(view)
      original = super
      original.merge('requests' => original.fetch('searches'), 'searches' => @journeys.fetch(view).count, 'journey_count' => @journeys.fetch(view).count)
    end

    def comparison_for(view, request_source: nil)
      original = super
      count = request_source.nil? || request_source == 'frontend' ? @journeys.fetch(view).count : 0
      original.merge('requests' => original.fetch('searches'), 'searches' => count)
    end

    def trends(view)
      original = super
      journeys = @journeys.fetch(view).trend.index_by { |row| row.fetch('bucket') }
      requests = original.fetch('volume').index_by { |row| row.fetch('bucket') }
      buckets = (requests.keys + journeys.keys).uniq.sort
      volume = buckets.map do |bucket|
        sources = CloudwatchSnapshotQuery::REQUEST_SOURCES.index_with { 0 }.merge(requests.fetch(bucket, {}))
        row = sources.merge('bucket' => bucket)
        if journeys[bucket]
          row.merge(journeys.fetch(bucket))
        elsif journey_collected?(bucket)
          row.merge(Period::VIEWS.index_with { 0 })
        else
          row
        end
      end
      original.merge('volume' => volume)
    end

    def latency_for(view, request_source: nil)
      return if request_source

      types = CloudwatchSnapshotQuery::VIEW_SEARCH_TYPES[view]
      rows = types ? @histogram.select { |row| types.include?(row['search_type']) } : @histogram
      LatencyHistogram.percentile(rows)
    end

    def status_for_latency(value) = LatencyStatus.call(value:, view: period.view)
    def rate(numerator, denominator) = denominator.zero? ? 0.0 : numerator.to_f / denominator

    def ai_costs(_view)
      { 'summary' => ai_cost_summary, 'trend' => ai_cost_trend, 'operations' => ai_cost_operations, 'models' => ai_cost_models }
    end

    def ai_cost_summary(*) = super.merge('p50_cost_usd' => nil, 'p90_cost_usd' => nil)

    def grouped_terms(view)
      filtered_rows(improvement_term_rows, view).group_by { |row| row.values_at('query', 'term_type') }.filter_map do |(query, type), rows|
        next if query.blank?

        { 'query' => query, 'term_type' => type, 'zero_results' => rows.sum { |row| integer(row['zero_results']) } }
      end
    end
  end
end
