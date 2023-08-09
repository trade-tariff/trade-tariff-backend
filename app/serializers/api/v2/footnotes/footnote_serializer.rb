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
                   :validity_start_date,
                   :validity_end_date

        has_many :goods_nomenclatures, serializer: Api::V2::Shared::GoodsNomenclatureSerializer.serializer_proc
      end
    end
  end
end
