module Api
  module V2
    module Subheadings
      class SubheadingSerializer
        include JSONAPI::Serializer

        set_type :subheading

        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_item_id,
                   :goods_nomenclature_sid,
                   :number_indents,
                   :producline_suffix,
                   :description,
                   :formatted_description,
                   :validity_start_date,
                   :validity_end_date,
                   :description_plain

        attribute :declarable do
          false
        end

        has_one :section, serializer: Api::V2::Subheadings::SectionSerializer
        has_one :chapter, serializer: Api::V2::Subheadings::ChapterSerializer
        has_one :heading, serializer: Api::V2::Subheadings::HeadingSerializer
        has_many :commodities, serializer: Api::V2::Subheadings::CommoditySerializer
        has_many :footnotes, serializer: Api::V2::Subheadings::FootnoteSerializer

        has_many :ancestors,
                 serializer: Api::V2::Commodities::CommoditySerializer,
                 object_method_name: :ten_digit_ancestors,
                 id_method_name: :ten_digit_ancestor_ids
      end
    end
  end
end
