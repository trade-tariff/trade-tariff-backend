require_relative './delta_tables_generator/logger'

require 'active_support/notifications'
require 'active_support/log_subscriber'

module DeltaTablesGenerator
  # Starts the generation of the deltas data.
  def self.generate(day: Date.current)
    ActiveSupport::Notifications.instrument('generate.delta_tables_generator', day: day) do
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
      return nil
    rescue StandardError => e
      ActiveSupport::Notifications.instrument('failed_generation.delta_tables_generator', exception: e)
      raise e.original
    end
  end

  def self.generate_backlog(from: Date.current.ago(3.months), to: Date.current)
    ActiveSupport::Notifications.instrument('generate_backlog.delta_tables_generator', from: from, to: to) do
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
      return nil
    rescue StandardError => e
      ActiveSupport::Notifications.instrument('failed_generation.delta_tables_generator', exception: e)
      raise e.original
    end
  end

  def self.cleanup_outdated(cleanup_older_than: Date.current.ago(3.months))
    ActiveSupport::Notifications.instrument('cleanup_outdated.delta_tables_generator', cleanup_older_than: cleanup_older_than) do
      CleanupOutdatedDeltas.run(cleanup_older_than: cleanup_older_than)
      return nil
    rescue StandardError => e
      ActiveSupport::Notifications.instrument('failed_generation.delta_tables_generator', exception: e)
      raise e.original
    end
  end
end
