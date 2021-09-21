module Api
  module V2
    module Headings
      class DeclarableHeadingSerializer
        include JSONAPI::Serializer

        set_type :heading

        set_id :goods_nomenclature_sid

        attributes :goods_nomenclature_item_id,
                   :validity_start_date,
                   :description,
                   :description_plain,
                   :formatted_description,
                   :producline_suffix,
                   :validity_end_date,
                   :bti_url,
                   :basic_duty_rate,
                   :meursing_code

        attribute :declarable do
          true
        end

        has_many :footnotes, serializer: Api::V2::Headings::FootnoteSerializer
        has_one :section, serializer: Api::V2::Headings::SectionSerializer
        has_one :chapter, serializer: Api::V2::Headings::ChapterSerializer
        has_many :import_measures, record_type: :measure, serializer: Api::V2::Measures::MeasureSerializer
        has_many :export_measures, record_type: :measure, serializer: Api::V2::Measures::MeasureSerializer

        meta do |commodity|
          {
            duty_calculator: {
              applicable_additional_codes: commodity.applicable_additional_codes,
              applicable_measure_units: commodity.applicable_measure_units,
              applicable_vat_options: commodity.applicable_vat_options,
              entry_price_system: commodity.entry_price_system?,
              meursing_code: commodity.meursing_code,
              source: TradeTariffBackend.service,
              trade_defence: commodity.trade_remedies?,
              zero_mfn_duty: commodity.zero_mfn_duty?,
            },
          }
        end
      end
    end
  end
end
