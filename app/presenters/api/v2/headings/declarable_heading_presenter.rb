module Api
  module V2
    module Headings
      class DeclarableHeadingPresenter < SimpleDelegator
        attr_reader :heading,
                    :import_measures,
                    :export_measures,
                    :unit_measures,
                    :third_country_measures

        delegate :id, to: :import_trade_summary, prefix: true

        def initialize(heading, measures)
          super(heading)
          @heading = heading
          @filtering_by_country = measures.filtering_by_country?
          @import_measures = measures.select(&:import).map do |measure|
            Api::V2::Measures::MeasurePresenter.new(measure, self)
          end
          @export_measures = measures.select(&:export).map do |measure|
            Api::V2::Measures::MeasurePresenter.new(measure, self)
          end
          @unit_measures = import_measures.select(&:expresses_unit?)
          @third_country_measures = import_measures.select(&:third_country?)
        end

        def import_measure_ids
          import_measures.map(&:measure_sid)
        end

        def export_measure_ids
          export_measures.map(&:measure_sid)
        end

        def footnote_ids
          footnotes.map(&:id)
        end

        def chapter_id
          heading.chapter.goods_nomenclature_sid
        end

        def meursing_code?
          import_measures.any?(&:meursing?)
        end
        alias_method :meursing_code, :meursing_code?

        def zero_mfn_duty?
          third_country_measures.size.positive? && third_country_measures.all?(&:zero_mfn?)
        end

        def trade_remedies?
          import_measures.any?(&:trade_remedy?)
        end

        def entry_price_system?
          return false if TradeTariffBackend.uk?

          import_measures.any?(&:entry_price_system?)
        end

        def basic_duty_rate
          if third_country_measures.one?
            third_country_measures.first&.formatted_duty_expression
          end
        end

        def applicable_additional_codes
          ApplicableAdditionalCodeService.new(import_measures).call
        end

        def applicable_measure_units
          MeasureUnitService.new(unit_measures).call
        end

        def applicable_vat_options
          ApplicableVatOptionsService.new(import_measures).call
        end

        def import_trade_summary
          ImportTradeSummary.build(import_measures)
        end

        def special_nature?(_presented_measure = nil)
          @special_nature ||= import_measures.any?(&:special_nature?)
        end

        def authorised_use_provisions_submission?
          @authorised_use_provisions_submission ||=
            filtering_by_country? && import_measures.any?(&:authorised_use_provisions_submission?)
        end

        def filtering_by_country?
          @filtering_by_country
        end
      end
    end
  end
end
