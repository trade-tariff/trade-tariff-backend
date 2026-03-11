module Sequel
  module Plugins
    module HasPaperTrail
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
            whodunnit: Thread.current[:paper_trail_whodunnit],
            created_at: Time.current,
          )
        end

        def item_id_for_version
          id = pk
          id.is_a?(Array) ? id.first.to_s : id.to_s
        end

        def values_for_version
          values.transform_keys(&:to_s)
        end
      end
    end
  end
end
