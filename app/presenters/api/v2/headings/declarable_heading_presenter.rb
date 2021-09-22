module Api
  module V2
    module Headings
      class DeclarableHeadingPresenter < SimpleDelegator
        attr_reader :heading,
                    :import_measures,
                    :export_measures,
                    :unit_measures,
                    :third_country_measures

        def initialize(heading, measures)
          super(heading)
          @heading = heading
          @import_measures = measures.select(&:import).map do |measure|
            Api::V2::Measures::MeasurePresenter.new(measure, heading)
          end
          @export_measures = measures.select(&:export).map do |measure|
            Api::V2::Measures::MeasurePresenter.new(measure, heading)
          end
          @unit_measures = @import_measures.select(&:expresses_unit?)
          @third_country_measures = import_measures.select(&:third_country?)
        end

        def import_measure_ids
          import_measures.map(&:measure_sid)
        end

        def export_measure_ids
          export_measures.map(&:measure_sid)
        end

        def footnote_ids
          footnotes.map(&:footnote_id)
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
          import_measures.any?(&:entry_price_system?)
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
      end
    end
  end
end
