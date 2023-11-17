module Sequel
  module Plugins
    module National
      module DatasetMethods
        def national
          pk = Sequel.qualify(model.table_name, model.primary_key)

          # rubocop:disable Style/NumericPredicate
          where { pk < 0 }.order(pk.desc)
          # rubocop:enable Style/NumericPredicate
        end
      end

      module ClassMethods
        Plugins.def_dataset_methods self, [:national]

        def next_national_sid
          x_model = national.last
          sid = if x_model
                  x_model.send(primary_key)
                else
                  0
                end
          sid - 1
        end
      end
    end
  end
end
