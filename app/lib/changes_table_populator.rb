require_relative './changes_table_populator/logger'

require 'active_support/notifications'
require 'active_support/log_subscriber'

module ChangesTablePopulator
  # Starts the generation of the changes data.
  def self.populate(day: Time.zone.today)
    ActiveSupport::Notifications.instrument('populate.changes_table_populator', day: day) do
      [
        CommodityCodeEndDated,
        CommodityCodeStarted,
        CommodityCodeDescriptionChanged,
        MeasureEndDated,
        MeasureStarted,
        MeasureDeleted,
        MeasureCreatedOrUpdated,
      ].map do |importer|
        importer.populate(day: day)
      end
      return nil
    rescue StandardError => e
      ActiveSupport::Notifications.instrument('populate_failed.changes_table_populator', exception: e)
      raise e.original
    end
  end

  def self.populate_backlog(from: 3.months.ago.beginning_of_day, to: Time.zone.today)
    ActiveSupport::Notifications.instrument('populate_backlog.changes_table_populator', from: from, to: to) do
      [
        CommodityCodeEndDated,
        CommodityCodeStarted,
        CommodityCodeDescriptionChanged,
        MeasureEndDated,
        MeasureStarted,
        MeasureDeleted,
        MeasureCreatedOrUpdated,
      ].map do |importer|
        importer.populate_backlog(from: from, to: to)
      end
      return nil
    rescue StandardError => e
      ActiveSupport::Notifications.instrument('populate_failed.changes_table_populator', exception: e)
      raise e.original
    end
  end

  def self.cleanup_outdated(older_than: 3.months.ago.beginning_of_day)
    ActiveSupport::Notifications.instrument('cleanup_outdated.changes_table_populator', older_than: older_than) do
      Change.cleanup(older_than: older_than)
      return nil
    rescue StandardError => e
      ActiveSupport::Notifications.instrument('cleanup_failed.changes_table_populator', exception: e)
      raise e.original
    end
  end
end
