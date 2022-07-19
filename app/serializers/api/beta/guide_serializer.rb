module Api
  module Beta
    class GuideSerializer
      include JSONAPI::Serializer
      set_type :guide

      attributes :title,
                 :url,
                 :image,
                 :strapline
    end
  end
end
