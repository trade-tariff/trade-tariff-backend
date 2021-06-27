require 'logger'

require 'active_support/notifications'
require 'active_support/log_subscriber'

module DeltaTablesGenerator
  extend self

  delegate :instrument, :subscribe, to: ActiveSupport::Notifications

  # Starts the generation of the deltas data.
  def generate(day: Date.current)
    DeltaTablesBackend.with_redis_lock do
      instrument('generate.delta_tables_generator', day: day) do
        begin
          [
            CommodityCodeEndDated,
            CommodityCodeStarted,
            CommodityCodeDescriptionChanged,
            MeasureEndDated,
            MeasureStarted,
            MeasureDeleted,
            MeasureCreatedOrUpdated,
          ].map do |importer|
            importer.perform_import(day: day)
          end
          return true
        rescue StandardError => e
          instrument('failed_generation.delta_tables_generator', exception: e)
          raise e.original
        end
      end
    end
  end

  def generate_backlog(from: Date.current - 3.months, to: Date.current)
    DeltaTablesBackend.with_redis_lock do
      instrument('generate_backlog.delta_tables_generator', from: from, to: to) do
        begin
          [
            CommodityCodeEndDated,
            CommodityCodeStarted,
            CommodityCodeDescriptionChanged,
            MeasureEndDated,
            MeasureStarted,
            MeasureDeleted,
            MeasureCreatedOrUpdated,
          ].map do |importer|
            importer.perform_backlog_import(from: from, to: to)
          end
          return true
        rescue StandardError => e
          instrument('failed_generation.delta_tables_generator', exception: e)
          raise e.original
        end
      end
    end
  end
end
