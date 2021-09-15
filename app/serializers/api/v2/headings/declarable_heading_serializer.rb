module Api
  module V2
    module Headings
      class DeclarableHeadingSerializer
        include JSONAPI::Serializer

        set_type :heading

        set_id :goods_nomenclature_sid

        attributes :validity_start_date, :validity_end_date, :goods_nomenclature_item_id, :description, :bti_url,
                   :formatted_description, :basic_duty_rate, :meursing_code

        attribute :declarable do
          true
        end

        has_many :footnotes, serializer: Api::V2::Headings::FootnoteSerializer
        has_one :section, serializer: Api::V2::Headings::SectionSerializer
        has_one :chapter, serializer: Api::V2::Headings::ChapterSerializer
        has_many :import_measures, record_type: :measure, serializer: Api::V2::Measures::MeasureSerializer
        has_many :export_measures, record_type: :measure, serializer: Api::V2::Measures::MeasureSerializer
      end
    end
  end
end
