module Api
  module User
    class CommodityChangeSerializer
      include JSONAPI::Serializer

      set_type :commodity_change

      set_id :id

      attributes :description, :count
    end
  end
end
