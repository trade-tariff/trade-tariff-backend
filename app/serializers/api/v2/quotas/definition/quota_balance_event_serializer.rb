module Api
  module V2
    module Quotas
      module Definition
        class QuotaBalanceEventSerializer
          include JSONAPI::Serializer

          set_type :quota_balance_event

          attributes :quota_definition_sid,
                     :occurrence_timestamp,
                     :last_import_date_in_allocation,
                     :old_balance,
                     :new_balance,
                     :imported_amount
        end
      end
    end
  end
end
