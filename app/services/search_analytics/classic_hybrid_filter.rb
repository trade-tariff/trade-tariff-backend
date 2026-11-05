# frozen_string_literal: true

module SearchAnalytics
  class ClassicHybridFilter
    def self.call(source:, log_stream_filter:)
      <<~SQL
        (request_id IS NULL OR request_id = '' OR request_id NOT IN (
          SELECT request_id FROM #{source}
          WHERE #{log_stream_filter} AND service = 'search'
            AND event = 'interactive_configuration_used' AND skip_question = true
            AND request_source = 'frontend' AND request_id IS NOT NULL AND request_id != ''
        ))
      SQL
    end
  end
end
