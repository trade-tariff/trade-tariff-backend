# frozen_string_literal: true

module SearchExport
  class Journey < Sequel::Model(:search_export_journeys)
    plugin :timestamps, update_on_create: true

    def self.upsert_terminal(attributes)
      now = Time.current
      values = attributes.merge(updated_at: now, created_at: now, omitted: false, truncated: false)
      dataset.insert_conflict(
        target: :request_id,
        update: values.except(:request_id, :created_at),
      ).insert(values)
    end

    def self.for_export(from:, to:)
      where(service: TradeTariffBackend.service, request_source: TradeTariffRequest::FRONTEND_REQUEST_SOURCE)
        .where { terminal_at >= Time.utc(from.year, from.month, from.day) }
        .where { terminal_at < Time.utc(to.year, to.month, to.day) + 1.day }
        .order(:terminal_at, :request_id)
    end

    def self.omit(request_id)
      return if request_id.blank?

      where(request_id:).update(omitted: true, updated_at: Time.current)
    end
  end
end
