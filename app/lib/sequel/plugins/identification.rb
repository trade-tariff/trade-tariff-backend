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

        def [](key)
          if [:id, 'id'].include?(key)
            id
          else
            super
          end
        end

        def identifier
          identification.values.compact.join('-')
        end

        def id
          super.presence || identifier
        end

        def oplog?
          self.class.plugins.include?(Sequel::Plugins::Oplog)
        end
      end
    end
  end
end
