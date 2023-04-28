module Api
  module V2
    class GeographicalAreaSerializer
      include JSONAPI::Serializer

      set_id :id

      set_type :geographical_area

      attributes :id, :description, :geographical_area_id, :geographical_area_sid
    end
  end
end
