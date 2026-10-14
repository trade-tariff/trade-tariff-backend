module Sequel
  module Plugins
    module SaveBang
      module ClassMethods
        def create!(values = OPTS, &block)
          new(values, &block).save!
        end

        Plugins.def_dataset_methods(self, %i[update! destroy!])
      end

      module InstanceMethods
        def save!(opts = OPTS)
          save(opts.merge(raise_on_failure: true))
        end

        def update!(hash)
          set_restricted(hash, :default)
          save_changes(raise_on_failure: true)
        end

        def destroy!(opts = OPTS)
          destroy(opts.merge(raise_on_failure: true))
        end
      end

      module DatasetMethods
        def update!(*args, &block)
          update(*args, &block)
        end

        def destroy!(*args, &block)
          destroy(*args, &block)
        end
      end
    end
  end
end
