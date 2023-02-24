# Based on: https://github.com/jeremyevans/sequel/blob/master/lib/sequel/plugins/single_table_inheritance.rb

module Sequel
  module Plugins
    module Sti
      def self.configure(model, opts = {})
        model.instance_eval do
          @class_determinator = opts[:class_determinator]
          @dataset = @dataset.with_row_proc(model.method(:sti_load))
        end
      end

      module ClassMethods
        attr_reader :class_determinator

        # Raises deprecation warning if model is not declared
        # as dataset method
        Plugins.def_dataset_methods self, [:model]

        def inherited(subclass)
          super

          cd = class_determinator
          rp = dataset.row_proc
          subclass.instance_eval do
            dataset.with_row_proc(rp)
            @class_determinator = cd
            @dataset = @dataset.with_row_proc(model.method(:sti_load))
          end
        end

        def sti_load(record)
          constantize(class_determinator.call(record)).call(record)
        end
      end
    end
  end
end
