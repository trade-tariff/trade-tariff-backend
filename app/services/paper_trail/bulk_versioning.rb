module PaperTrail
  class BulkVersioning
    class << self
      def record_current_versions_for_dataset!(model:, dataset:)
        item_ids = dataset.select_map(model.primary_key)
        record_current_versions_for_item_ids!(model:, item_ids:)
      end

      def record_current_versions_for_item_ids!(model:, item_ids:)
        return 0 if item_ids.empty?

        model.where(model.primary_key => item_ids).all.count do |record|
          Sequel::Plugins::HasPaperTrail.record_current_version!(record)
        end
      end

      def record_destroy_versions_for_dataset!(dataset:)
        dataset.all.count do |record|
          Sequel::Plugins::HasPaperTrail.record_version!(record, event: 'destroy')
        end
      end
    end
  end
end
