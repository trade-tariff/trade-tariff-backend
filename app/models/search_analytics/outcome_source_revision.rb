# frozen_string_literal: true

module SearchAnalytics
  class OutcomeSourceRevision < Sequel::Model(:search_analytics_outcome_source_revisions)
    include MaterializedView

    set_primary_key %i[service reporting_date name]
  end
end
