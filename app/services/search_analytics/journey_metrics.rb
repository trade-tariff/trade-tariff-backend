# frozen_string_literal: true

module SearchAnalytics
  class JourneyMetrics
    def initialize(rows:, period:)
      @rows = rows.select { |row| row['request_source'] == 'frontend' }
      @period = period
    end

    def keys
      keys_for(@rows, @period.view)
    end

    def count = keys.size
    def all_keys = keys_for(@rows, 'all')

    # A journey is counted once per displayed bucket. The range headline is
    # independently deduplicated across all buckets, not summed from this trend.
    def trend
      @rows.group_by { |row| bucket(row.fetch('@timestamp')) }.sort.map do |time, rows|
        { 'bucket' => time }.merge(CloudwatchSnapshotQuery::VIEWS.index_with { |view| keys_for(rows, view).size })
      end
    end

  private

    def keys_for(rows, view)
      types = CloudwatchSnapshotQuery::VIEW_SEARCH_TYPES[view]
      rows.each_with_object({}) do |row, keys|
        next unless types.nil? || types.include?(row['search_type'])

        row.fetch('journey_keys').each { |key| keys[key] = true }
      end
    end

    def bucket(value)
      time = Time.find_zone!('UTC').parse(value)
      (@period.single_day? ? time.beginning_of_hour : time.beginning_of_day).iso8601
    end
  end
end
