module Api
  module V2
    module GreenLanes
      class ThemeSerializer
        include JSONAPI::Serializer

        set_id :code

        attribute :section, &:code
        attribute :theme, &:description
        attribute :category
      end
    end
  end
end
