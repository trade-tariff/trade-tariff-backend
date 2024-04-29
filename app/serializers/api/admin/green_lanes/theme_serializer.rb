module Api
  module Admin
    module GreenLanes
      class ThemeSerializer
        include JSONAPI::Serializer

        set_type :theme

        set_id :id

        attributes :section,
                   :subsection,
                   :theme,
                   :description,
                   :category
      end
    end
  end
end
