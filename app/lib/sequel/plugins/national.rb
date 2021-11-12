module Sequel
  module Plugins
    module National
      module DatasetMethods
        def national
          where(Sequel.qualify(model.table_name, model.primary_key) < 0).order(Sequel.qualify(model.table_name, model.primary_key).desc)
        end
      end

      module ClassMethods
        Plugins.def_dataset_methods self, [:national]

        def next_national_sid
          x_model = self.national.last
          if x_model
            sid = x_model.send(self.primary_key)
          else
            sid = 0
          end
          sid - 1
        end
      end
    end
  end
end
