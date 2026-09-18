# frozen_string_literal: true

module SearchAnalytics
  # Exists so a read can refuse stale cache.
  # Record which search_journeys and journey_outcomes rows built the other
  # views. Matching live results means the stored answers are current. This is
  # not a history of refreshes.
  class SourceRevision < Sequel::Model(:search_analytics_source_revisions)
    include MaterializedView

    set_primary_key %i[service reporting_date name]
  end
end
