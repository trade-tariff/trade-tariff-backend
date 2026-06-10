# frozen_string_literal: true

class SearchAnalyticsSnapshot < Sequel::Model(Sequel[:search_analytics_snapshots].qualify(:public))
  plugin :auto_validations, not_null: :presence
  plugin :timestamps, update_on_create: true

  dataset_module do
    def latest_for(service:, period:, view:)
      where(service:, period:, view:).order(Sequel.desc(:generated_at), Sequel.desc(:data_through)).first
    end
  end

  def validate
    super
    validates_unique %i[service period view generated_at]
  end
end
