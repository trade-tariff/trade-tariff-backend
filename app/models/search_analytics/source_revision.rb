# frozen_string_literal: true

module SearchAnalytics
  # Snapshot of the search_journeys and journey_outcomes rows used to build the
  # other views: id, service, date, name, fingerprint, collected_at and
  # definition_version. A read compares this to live query results. Matching
  # revisions mean the cache is current. This is a freshness checklist, not a
  # history of refreshes.
  class SourceRevision < Sequel::Model(:search_analytics_source_revisions)
    include MaterializedView

    set_primary_key %i[service reporting_date name]
  end
end
