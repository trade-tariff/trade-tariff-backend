module TradeTariffBackend
  class DataMigration
    module BlockAccessor
      extend ActiveSupport::Concern

      module ClassMethods
        def block_accessor(*names)
          mod = Module.new

          names.each do |name|
            mod.module_eval(%Q{
              def #{name}(&block)
                if block
                  instance_variable_set(:"@#{name}", block)
                else
                  instance_variable_get(:"@#{name}").call
                end
              end
            })
          end

          include mod
        end
      end
    end
  end
end
