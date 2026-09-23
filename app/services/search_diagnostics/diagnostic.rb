module SearchDiagnostics
  class Diagnostic < SimpleDelegator
    attr_reader :experiment, :browser_session_id, :related_requests, :related_requests_available

    def self.compose(result, correlation)
      new(
        result,
        experiment: experiment_from(result) || correlation&.experiment,
        browser_session_id: correlation&.browser_session_id,
        related_requests: correlation&.requests || [],
        related_requests_available: !correlation.nil?,
      )
    end

    def self.experiment_from(result)
      result.events.filter_map { |event| event.fields['experiment'].presence || event.fields[:experiment].presence }.first
    end

    def initialize(result, experiment:, browser_session_id:, related_requests:, related_requests_available:)
      super(result)
      @experiment = experiment
      @browser_session_id = browser_session_id
      @related_requests = related_requests
      @related_requests_available = related_requests_available
    end
  end
end
