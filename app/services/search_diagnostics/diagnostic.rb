module SearchDiagnostics
  class Diagnostic < SimpleDelegator
    attr_reader :experiment, :browser_session_id, :related_requests

    def self.compose(result, correlation)
      new(
        result,
        experiment: experiment_from(result) || correlation.experiment,
        browser_session_id: correlation.browser_session_id,
        related_requests: correlation.requests,
      )
    end

    def self.experiment_from(result)
      result.events.filter_map { |event| event.fields['experiment'].presence || event.fields[:experiment].presence }.first
    end

    def initialize(result, experiment:, browser_session_id:, related_requests:)
      super(result)
      @experiment = experiment
      @browser_session_id = browser_session_id
      @related_requests = related_requests
    end
  end
end
