module Api
  module Internal
    class ProductDescriptionSerializer
      include JSONAPI::Serializer

      set_type :product_description
      set_id :source_url

      attributes :description, :source_url, :confidence, :metadata
    end
  end
end
