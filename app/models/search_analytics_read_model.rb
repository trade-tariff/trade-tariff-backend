# frozen_string_literal: true

class SearchAnalyticsReadModel < Sequel::Model
  VERSION = 1
  SOURCE_NAMES = %w[search_journeys journey_outcomes].freeze

  def self.versions(records)
    records.each_with_object({}) { |record, versions|
      next unless SOURCE_NAMES.include?(record.name)

      date = record.reporting_date.iso8601
      versions[date] ||= []
      versions[date] << [record.name, record.fingerprint, record.collected_at.iso8601(6), record.id]
    }.transform_values(&:sort)
  end

  def self.latest(service:, region:)
    where(service:, region:).order(Sequel.desc(:built_at), Sequel.desc(:id)).first
  end

  def compatible?(records:, definitions:, dates:)
    return false unless version == VERSION
    return false unless fingerprints.to_h.stringify_keys.slice(*SOURCE_NAMES) == definitions.slice(*SOURCE_NAMES)

    expected = self.class.versions(records.select { |record| dates.include?(record.reporting_date) })
    actual = source_versions.to_h.stringify_keys.slice(*dates.map(&:iso8601))
    actual == expected
  end

  def journey_days_dataset
    db[:search_analytics_journey_days].where(read_model_id: id)
  end

  def journey_rollups_dataset
    db[:search_analytics_journey_rollups].where(read_model_id: id)
  end

  def multi_day_observations_dataset
    db[:search_analytics_multi_day_observations].where(read_model_id: id)
  end
end
