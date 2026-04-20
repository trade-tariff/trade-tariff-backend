module Sequel
  module Plugins
    module HasPaperTrail
      @tracked_models = []

      class << self
        def apply(model, *_args)
          register_model(model)
        end

        def tracked_models
          @tracked_models.sort_by(&:name)
        end

        def version_item_id_for(record)
          id = record.pk
          id.is_a?(Array) ? id.first.to_s : id.to_s
        end

        def version_exists_for?(record)
          Version.where(item_type: record.model.name, item_id: version_item_id_for(record)).any?
        end

        def record_current_version!(record, whodunnit: TradeTariffRequest.whodunnit, created_at: Time.current)
          event = version_exists_for?(record) ? 'update' : 'create'
          record_version!(record, event:, whodunnit:, created_at:)
        end

        def record_version!(record, event:, whodunnit: TradeTariffRequest.whodunnit, created_at: Time.current)
          return false if record.nil?

          Version.create(
            item_type: record.model.name,
            item_id: version_item_id_for(record),
            event: event,
            object: Sequel.pg_jsonb_wrap(record.values.transform_keys(&:to_s)),
            whodunnit: whodunnit,
            created_at: created_at,
          )

          true
        end

        private

        def register_model(model)
          @tracked_models |= [model]
        end
      end

      module ClassMethods
        def without_paper_trail
          previous = Thread.current[paper_trail_disabled_key]
          Thread.current[paper_trail_disabled_key] = true
          yield
        ensure
          Thread.current[paper_trail_disabled_key] = previous
        end

        def paper_trail_disabled?
          Thread.current[paper_trail_disabled_key] == true
        end

        private

        def paper_trail_disabled_key
          :"paper_trail_disabled_#{name}"
        end
      end

      module InstanceMethods
        def versions
          Version.where(item_type: model.name, item_id: item_id_for_version)
                 .order(:created_at)
        end

        def after_create
          super
          create_version('create')
        end

        def after_update
          super
          create_version('update')
        end

        def after_destroy
          super
          create_version('destroy')
        end

        private

        def create_version(event)
          return if model.paper_trail_disabled?

          Version.create(
            item_type: model.name,
            item_id: item_id_for_version,
            event: event,
            object: Sequel.pg_jsonb_wrap(values_for_version),
            whodunnit: TradeTariffRequest.whodunnit,
            created_at: Time.current,
          )
        end

        def item_id_for_version
          HasPaperTrail.version_item_id_for(self)
        end

        def values_for_version
          values.transform_keys(&:to_s)
        end
      end
    end
  end
end
