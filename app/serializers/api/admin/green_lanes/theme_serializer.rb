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
                   :category,
                   :created_at,
                   :updated_at
      end
    end
  end
end
