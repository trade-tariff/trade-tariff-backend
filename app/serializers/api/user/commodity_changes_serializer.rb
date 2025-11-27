module Api
  module User
    class CommodityChangesSerializer
      include JSONAPI::Serializer

      set_type :commodity_changes

      set_id :id

      attributes :description, :count

      has_many :tariff_changes, serializer: Api::User::TariffChangeSerializer
    end
  end
end
