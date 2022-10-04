module Api
  module V2
    class GeographicalAreaTreeSerializer
      include JSONAPI::Serializer

      set_id :id

      set_type :geographical_area

      attributes :id,
                 :description,
                 :geographical_area_id,
                 :hjid

      has_many :contained_geographical_areas, key: :children_geographical_areas, serializer: Api::V2::GeographicalAreaTreeSerializer
    end
  end
end
