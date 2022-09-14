module Api
  module V2
    class ValidityPeriodPresenter < SimpleDelegator
      include ContentAddressableId

      content_addressable_fields :to_param,
                                 :validity_start_date,
                                 :validity_end_date
    end
  end
end
