module Api
  module V2
    module Footnotes
      class FootnoteSerializer
        include JSONAPI::Serializer

        set_type :footnote

        set_id :code

        attributes :code,
                   :footnote_type_id,
                   :footnote_id,
                   :description,
                   :formatted_description,
                   :extra_large_measures,
                   :validity_start_date,
                   :validity_end_date

        has_many :measures, serializer: Api::V2::Shared::MeasureSerializer
        has_many :goods_nomenclatures,
                 serializer: proc { |record, _params|
                   if record && record.respond_to?(:goods_nomenclature_class)
                     "Api::V2::Shared::#{record.goods_nomenclature_class}Serializer".constantize
                   else
                     Api::V2::Shared::GoodsNomenclatureSerializer
                   end
                 }
      end
    end
  end
end
