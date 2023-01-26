module Api
  module Admin
    module QuotaOrderNumbers
      class QuotaBalanceEventSerializer
        include JSONAPI::Serializer

        set_type :quota_balance_event

        attributes :occurrence_timestamp,
                   :new_balance,
                   :imported_amount,
                   :last_import_date_in_allocation,
                   :old_balance
      end
    end
  end
end
