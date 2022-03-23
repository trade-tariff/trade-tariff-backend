module Api
  module V2
    module Footnotes
      class FootnoteSerializer
        include JSONAPI::Serializer

        set_type :footnote

        set_id :code

        attributes :code, :footnote_type_id, :footnote_id, :description, :formatted_description, :extra_large_measures

        has_many :measures, serializer: Api::V2::Shared::MeasureSerializer
        has_many :goods_nomenclatures, serializer: proc { |record, _params| "Api::V2::Shared::#{record.goods_nomenclature_class}Serializer".constantize }
      end
    end
  end
end
