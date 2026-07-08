require 'active_support/notifications'

module Search
  module Instrumentation
    extend Core
    extend QueryEvents
    extend ApiEvents
    extend ResultEvents
    extend EvaluationEvents
    extend PayloadHelpers
    extend ClassicResultSummaries
    extend ResultSummaries

    ERROR_MESSAGE_MAX_LENGTH = 500
    MAX_LOGGED_RESULTS = 50
    EVALUATION_TRACE_VERSION = 'classification_evaluation_trace.v1'.freeze
  end
end
