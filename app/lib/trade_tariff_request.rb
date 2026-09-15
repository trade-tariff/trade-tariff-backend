class TradeTariffRequest < ActiveSupport::CurrentAttributes
  FRONTEND_USER_AGENT_PREFIX = 'TradeTariffFrontend/'.freeze
  ADMIN_USER_AGENT_PREFIX = 'TradeTariffAdmin/'.freeze
  MCP_USER_AGENT_PREFIX = 'TradeTariffMcp/'.freeze
  FRONTEND_REQUEST_SOURCE = 'frontend'.freeze
  ADMIN_REQUEST_SOURCE = 'admin'.freeze
  MCP_REQUEST_SOURCE = 'mcp'.freeze
  BACKEND_ONLY_REQUEST_SOURCE = 'backend_only'.freeze
  REQUEST_SOURCE_BY_USER_AGENT_PREFIX = {
    FRONTEND_USER_AGENT_PREFIX => FRONTEND_REQUEST_SOURCE,
    ADMIN_USER_AGENT_PREFIX => ADMIN_REQUEST_SOURCE,
    MCP_USER_AGENT_PREFIX => MCP_REQUEST_SOURCE,
  }.freeze

  attribute :whodunnit,
            :request_id,
            :request_source,
            :client_id,
            :experiment,
            :search_failures,
            :search_type,
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
    agent = user_agent.to_s

    REQUEST_SOURCE_BY_USER_AGENT_PREFIX.each do |prefix, source|
      return source if agent.start_with?(prefix)
    end

    BACKEND_ONLY_REQUEST_SOURCE
  end
end
