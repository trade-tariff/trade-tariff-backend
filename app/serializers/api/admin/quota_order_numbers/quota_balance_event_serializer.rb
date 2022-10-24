module Api
  module Admin
    module QuotaOrderNumbers
      class QuotaBalanceEventSerializer
        include JSONAPI::Serializer

        set_type :quota_balance_event

        attributes :occurrence_timestamp,
                   :new_balance,
                   :imported_amount
      end
    end
  end
end
