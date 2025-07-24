require_relative './myott_logger'

require 'active_support/notifications'
require 'active_support/log_subscriber'

module ChangesTablePopulator
  module MyottChangesTablePopulator
    # Starts the generation of the changes data.
    def self.populate(day: Time.zone.today)
      ActiveSupport::Notifications.instrument('populate.myott_changes_table_populator', day:) do
        [
          MyottCommodityCodeEndDated,
          MyottCommodityCodeCreated,
          MyottCommodityDescriptionChanged,
          # MeasureEndDated,
          # MeasureStarted,
          # MeasureDeleted,
          # MeasureCreatedOrUpdated,
        ].map do |importer|
          importer.new(day).populate
        end
        return nil
      rescue StandardError => e
        ActiveSupport::Notifications.instrument('populate_failed.myott_changes_table_populator', exception: e)
        raise
      end
    end

    def self.populate_backlog(from: 3.months.ago.beginning_of_day, to: Time.zone.today)
      ActiveSupport::Notifications.instrument('populate_backlog.myott_changes_table_populator', from:, to:) do
        [
          MyottCommodityCodeEndDated,
          MyottCommodityCodeCreated,
          MyottCommodityDescriptionChanged,
          # MeasureEndDated,
          # MeasureStarted,
          # MeasureDeleted,
          # MeasureCreatedOrUpdated,
        ].map do |importer|
          importer.populate_backlog(from:, to:)
        end
        return nil
      rescue StandardError => e
        ActiveSupport::Notifications.instrument('populate_failed.myott_changes_table_populator', exception: e)
        raise
      end
    end

    def self.cleanup_outdated(older_than: 3.months.ago.beginning_of_day)
      ActiveSupport::Notifications.instrument('cleanup_outdated.myott_changes_table_populator', older_than:) do
        MyottChange.cleanup(older_than:)
        return nil
      rescue StandardError => e
        ActiveSupport::Notifications.instrument('cleanup_failed.myott_changes_table_populator', exception: e)
        raise
      end
    end
  end
end
