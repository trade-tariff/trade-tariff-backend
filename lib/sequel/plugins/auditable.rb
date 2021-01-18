# Keeps a record of the changes after update
module Sequel
  module Plugins
    module Auditable

      def self.configure(model, options = {})

        model.plugin :dirty

        # Associations
        model.one_to_many :audits, key: :auditable_id, reciprocal: :auditable, conditions: {auditable_type: model.to_s},
                                   adder: proc{|asset| asset.update(auditable_id: model.primary_key, auditable_type: model.to_s)},
                                   remover: proc{|asset| asset.update(auditable_id: nil, auditable_type: nil)},
                                   clearer: proc{assets_dataset.update(auditable_id: nil, auditable_type: nil)}
      end

      module InstanceMethods

        def before_update
          Audit.create(action: 'update', changes: Sequel.pg_json(column_changes), auditable: self)
          super
        end
      end
    end
  end
end
