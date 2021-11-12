# Based on: https://github.com/jeremyevans/sequel/blob/master/lib/sequel/plugins/single_table_inheritance.rb

module Sequel
  module Plugins
    module Sti
      def self.configure(model, opts = {})
        model.instance_eval do
          @class_determinator = opts[:class_determinator]
          dataset.with_row_proc(lambda { |r| model.sti_load(r) })
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
            dataset.with_row_proc(lambda { |r| model.sti_load(r) })
          end
        end

        def sti_load(r)
          constantize(class_determinator.call(r)).call(r)
        end
      end
    end
  end
end
