class TradeTariffRequest < ActiveSupport::CurrentAttributes
  FRONTEND_USER_AGENT_PREFIX = 'TradeTariffFrontend/'.freeze
  FRONTEND_REQUEST_SOURCE = 'frontend'.freeze
  BACKEND_ONLY_REQUEST_SOURCE = 'backend_only'.freeze

  attribute :whodunnit,
            :request_id,
            :request_source,
            :client_id,
            :experiment,
            :search_failures,
            :green_lanes,
            :time_machine_now,
            # Controls how TimeMachine filters associated records in queries.
            # When false/nil: associations use the global time_machine_now timestamp
            # When true: associations use the parent record's validity period
            # This is critical for indexing - when indexing historical records, we want
            # associations that were valid during that record's lifetime, not at an arbitrary point in time
            :time_machine_relevant,
            :meursing_additional_code_id,
            # Controls whether label fields (known_brands, colloquial_terms, synonyms)
            # are included in search suggestion queries
            :search_labels_enabled

  def record_search_failure(code)
    unless Search::FailureCodes::ALL.include?(code)
      raise ArgumentError, "Unknown search failure: #{code}"
    end

    self.search_failures = Array(search_failures) | [code]
  end

  def search_failed?(code)
    Array(search_failures).include?(code)
  end

  def self.request_source_for_user_agent(user_agent)
    if user_agent.to_s.start_with?(FRONTEND_USER_AGENT_PREFIX)
      FRONTEND_REQUEST_SOURCE
    else
      BACKEND_ONLY_REQUEST_SOURCE
    end
  end
end
