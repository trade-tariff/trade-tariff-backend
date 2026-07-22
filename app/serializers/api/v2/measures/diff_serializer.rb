module Api
  module V2
    module Measures
      class DiffSerializer
        OPERATION_LABELS = {
          'C' => 'created',
          'U' => 'updated',
          'D' => 'deleted',
        }.freeze

        include JSONAPI::Serializer

        set_type :measure_operation
        set_id :oid

        attributes :measure_sid,
                   :measure_type_id,
                   :goods_nomenclature_item_id,
                   :geographical_area_id,
                   :validity_start_date,
                   :validity_end_date,
                   :measure_generating_regulation_id,
                   :operation_date

        attribute :operation do |record|
          OPERATION_LABELS.fetch(record[:operation], record[:operation])
        end
      end
    end
  end
end
