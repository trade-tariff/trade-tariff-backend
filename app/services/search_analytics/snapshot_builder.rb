# frozen_string_literal: true

module SearchAnalytics
  class SnapshotBuilder
    SEARCH_EVENTS = %w[search_completed search_failed].freeze
    COMPLETED_EVENT = 'search_completed'
    FAILED_EVENT = 'search_failed'
    SELECTION_EVENT = 'result_selected'
    IMPROVEMENT_TERM_LIMIT = 100
    VIEW_SEARCH_TYPES = {
      'classic' => %w[classic],
      'internal' => %w[interactive internal],
    }.freeze

    def self.call(rows:, period:, view:, now: Time.current)
      new(rows:, period:, view:, now:).call
    end

    def initialize(rows:, period:, view:, now: Time.current)
      @rows = rows
      @period = Period.for(period:, view:)
      @now = now
    end

    def call
      {
        'summary' => summary,
        'summary_statuses' => summary_statuses,
        'trends' => trends,
        'comparisons' => comparisons,
        'improvement_terms' => improvement_terms,
      }
    end

    private

    attr_reader :rows, :period, :now

    def scoped_rows
      @scoped_rows ||= if period.view == 'all'
                         rows
                       else
                         rows.select { |row| row_matches_view?(row, period.view) || selection_matches_view?(row, period.view) }
                       end
    end

    def search_rows(scope = scoped_rows)
      scope.select { |row| SEARCH_EVENTS.include?(row['event']) }
    end

    def completed_rows(scope = scoped_rows)
      scope.select { |row| row['event'] == COMPLETED_EVENT }
    end

    def failed_rows(scope = scoped_rows)
      scope.select { |row| row['event'] == FAILED_EVENT }
    end

    def selection_rows(scope = scoped_rows)
      scope.select { |row| row['event'] == SELECTION_EVENT }
    end

    def summary
      @summary ||= begin
        searches = summary_search_rows.count
        completed = completed_rows
        zero_results = zero_result_rows(completed).count
        eligible = selectable_search_rows(completed).count

        {
          'searches' => searches,
          'failure_rate' => rate(failed_rows.count, searches),
          'zero_result_rate' => rate(zero_results, completed.count),
          'selection_rate' => rate(attributed_selection_rows.count, eligible),
          'p90_latency_ms' => percentile(duration_values(summary_search_rows), 90),
        }
      end
    end

    def trends
      {
        'volume' => volume_trend,
        'outcomes' => outcome_trend,
      }
    end

    def volume_trend
      trend_buckets.map do |bucket, bucket_rows|
        volume_rows = search_rows(bucket_rows)

        {
          'bucket' => bucket.iso8601,
          'all' => volume_rows.count,
          'classic' => volume_rows.count { |row| SEARCH_EVENTS.include?(row['event']) && row_matches_view?(row, 'classic') },
          'internal' => volume_rows.count { |row| SEARCH_EVENTS.include?(row['event']) && row_matches_view?(row, 'internal') },
        }
      end
    end

    def outcome_trend
      trend_buckets.map do |bucket, bucket_rows|
        completed = completed_rows(bucket_rows)

        {
          'bucket' => bucket.iso8601,
          'completed' => completed.count,
          'failed' => failed_rows(bucket_rows).count,
          'zero_result' => zero_result_rows(completed).count,
          'selected' => attributed_selection_rows(bucket_rows).count,
        }
      end
    end

    def trend_buckets
      scoped_rows.group_by { |row| bucket_for(row) }.sort.to_h
    end

    def comparisons
      {
        'classic' => comparison_for('classic'),
        'internal' => comparison_for('internal'),
      }
    end

    def comparison_for(view)
      rows_for_view = rows.select { |row| row_matches_view?(row, view) }
      completed = completed_rows(rows_for_view)
      searches = search_rows(rows_for_view).count
      zero_results = zero_result_rows(completed).count
      eligible = selectable_search_rows(completed).count

      {
        'searches' => searches,
        'zero_result_rate' => rate(zero_results, completed.count),
        'selection_rate' => rate(attributed_selection_rows(rows, view: view).count, eligible),
        'p90_latency_ms' => percentile(duration_values(rows_for_view), 90),
      }
    end

    def improvement_terms
      selected_request_ids = attributed_selected_request_ids

      terms = completed_rows
        .group_by { |row| row['query'].to_s }
        .filter_map do |query, query_rows|
          next if query.blank?

          zero_results = zero_result_rows(query_rows).count
          next if zero_results.zero?

          selections = query_rows.count { |row| selected_request_ids.include?(row['request_id']) }

          {
            'query' => query,
            'searches' => query_rows.count,
            'zero_results' => zero_results,
            'selection_rate' => rate(selections, query_rows.count),
          }
        end

      terms.sort_by { |term| [-term['zero_results'], term['query']] }
        .first(IMPROVEMENT_TERM_LIMIT)
    end

    def summary_statuses
      {
        'searches' => {
          'level' => 'neutral',
          'message' => 'Search volume is available for this period',
        },
        'failure_rate' => status_for_failure_rate,
        'zero_result_rate' => status_for_zero_result_rate,
        'selection_rate' => status_for_selection_rate,
        'p90_latency_ms' => status_for_latency,
      }
    end

    def status_for_failure_rate
      case summary.fetch('failure_rate')
      when 0...0.02 then { 'level' => 'good', 'message' => 'Failures are low' }
      when 0.02...0.05 then { 'level' => 'watch', 'message' => 'Failures are slightly higher than usual' }
      else { 'level' => 'problem', 'message' => 'Failures are higher than expected' }
      end
    end

    def status_for_zero_result_rate
      case summary.fetch('zero_result_rate')
      when 0...0.1 then { 'level' => 'good', 'message' => 'Most searches are returning results' }
      when 0.1...0.2 then { 'level' => 'watch', 'message' => 'Zero-result searches are slightly higher than usual' }
      else { 'level' => 'problem', 'message' => 'Many searches are returning no results' }
      end
    end

    def status_for_selection_rate
      if summary.fetch('selection_rate') >= 0.25
        { 'level' => 'good', 'message' => 'Selections are tracking eligible searches' }
      else
        { 'level' => 'watch', 'message' => 'Fewer searches are leading to selections' }
      end
    end

    def status_for_latency
      case summary.fetch('p90_latency_ms')
      when 0..1_000 then { 'level' => 'good', 'message' => 'Most searches are completing quickly' }
      when 1_001..3_000 then { 'level' => 'watch', 'message' => 'Some searches are taking longer than usual' }
      else { 'level' => 'problem', 'message' => 'Searches are taking too long' }
      end
    end

    def zero_result_rows(scope)
      scope.select { |row| integer(row['result_count']).zero? }
    end

    def selectable_search_rows(scope)
      scope.select { |row| selectable_search_row?(row) }
    end

    def selectable_search_row?(row)
      integer(row['result_count']).positive? &&
        (
          row['search_type'] == 'classic' && row['results_type'] == 'fuzzy_search' ||
          VIEW_SEARCH_TYPES.fetch('internal').include?(row['search_type']) && %w[opensearch vector hybrid].include?(row['results_type'])
        )
    end

    def summary_search_rows
      search_rows
    end

    def row_matches_view?(row, view)
      return true if view == 'all'

      VIEW_SEARCH_TYPES.fetch(view, [view]).include?(row['search_type'])
    end

    def selection_matches_view?(row, view)
      return false unless row['event'] == SELECTION_EVENT

      search = completed_search_by_request_id[row['request_id']]
      search.present? && row_matches_view?(search, view) && selectable_search_row?(search)
    end

    def attributed_selection_rows(scope = scoped_rows, view: period.view)
      selection_rows(scope).filter_map do |row|
        search = completed_search_by_request_id[row['request_id']]
        next unless search && row_matches_view?(search, view) && selectable_search_row?(search)

        row.merge(
          'query' => search['query'],
          'search_type' => search['search_type'],
        )
      end
    end

    def attributed_selected_request_ids(scope = scoped_rows, view: period.view)
      attributed_selection_rows(scope, view:)
        .map { |row| row['request_id'] }
        .uniq
    end

    def completed_search_by_request_id
      @completed_search_by_request_id ||= completed_rows(rows).index_by { |row| row['request_id'] }
    end

    def duration_values(scope)
      scope.filter_map { |row| integer_or_nil(row['total_duration_ms']) }
    end

    def bucket_for(row)
      timestamp = Time.zone.parse(row.fetch('@timestamp'))

      if period.bucket_size == 'hour'
        timestamp.change(min: 0, sec: 0)
      else
        timestamp.beginning_of_day
      end
    end

    def rate(numerator, denominator)
      return 0.0 if denominator.zero?

      (numerator.to_f / denominator).round(2)
    end

    def percentile(values, percentile)
      return 0 if values.empty?

      sorted = values.sort
      index = ((percentile / 100.0) * sorted.length).ceil - 1
      sorted.fetch(index)
    end

    def integer(value)
      Integer(value || 0)
    rescue ArgumentError, TypeError
      0
    end

    def integer_or_nil(value)
      return if value.blank?

      Integer(value)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
