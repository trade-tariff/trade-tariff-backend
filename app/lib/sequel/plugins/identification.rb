module Sequel
  module Plugins
    module Identification
      module InstanceMethods
        def identification
          composite_primary_key = Array.wrap(self.class.primary_key.dup)
          composite_primary_key.unshift(:oid) if oplog?

          composite_primary_key.index_with do |composite_primary_key_part|
            public_send(composite_primary_key_part)
          end
        end

        def oplog?
          self.class.plugins.include?(Sequel::Plugins::Oplog)
        end
      end
    end
  end
end
