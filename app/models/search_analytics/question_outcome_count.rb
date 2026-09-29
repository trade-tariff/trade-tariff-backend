# frozen_string_literal: true

module SearchAnalytics
  class QuestionOutcomeCount < Sequel::Model(:search_analytics_question_outcome_counts)
    include MaterializedView

    set_primary_key %i[service reporting_date outcome]
  end
end
