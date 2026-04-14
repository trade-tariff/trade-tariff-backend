module PaperTrail
  class ResetInitialVersions
    def call
      Sequel::Model.db.transaction do
        Version.dataset.truncate(restart: true)
        tracked_models.each { |model| reset_model_versions(model) }
      end
    end

    private

    def tracked_models
      Sequel::Plugins::HasPaperTrail.tracked_models
    end

    def reset_model_versions(model)
      model.each do |record|
        Version.insert(
          item_type: model.name,
          item_id: Sequel::Plugins::HasPaperTrail.version_item_id_for(record),
          event: 'create',
          object: Sequel.pg_jsonb_wrap(record.values.transform_keys(&:to_s)),
          whodunnit: nil,
          created_at: version_created_at_for(record),
        )
      end
    end

    def version_created_at_for(record)
      record.values[:created_at] || record.values[:updated_at] || Time.current
    end
  end
end
