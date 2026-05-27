module Api
  module Admin
    class CustomsTariffUpdateSerializer
      include JSONAPI::Serializer

      set_type :customs_tariff_update
      set_id   :version

      attributes :version, :status, :validity_start_date, :validity_end_date,
                 :source_url, :document_created_on, :created_at, :updated_at
    end
  end
end
