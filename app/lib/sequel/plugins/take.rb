module Sequel
  class RecordNotFound < StandardError; end

  module Plugins
    module Take
      module DatasetMethods
        def take(*cond, &block)
          dataset = cond.any? || block ? where(*cond, &block) : self
          dataset.limit(1).all.first.presence || (raise Sequel::RecordNotFound)
        end
      end

      module ClassMethods
        Plugins.def_dataset_methods self, [:take]
      end
    end
  end
end
