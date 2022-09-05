module Api
  module V2
    module Commodities
      class CommodityPresenter < SimpleDelegator
        attr_reader :commodity,
                    :footnotes,
                    :import_measures,
                    :export_measures,
                    :unit_measures

        def initialize(commodity, measures)
          super(commodity)
          @commodity = commodity
          @footnotes = commodity.footnotes + commodity.heading.footnotes
          @import_measures = measures.select(&:import).map do |measure|
            Api::V2::Measures::MeasurePresenter.new(measure, commodity)
          end
          @export_measures = measures.select(&:export).map do |measure|
            Api::V2::Measures::MeasurePresenter.new(measure, commodity)
          end
          @unit_measures = @import_measures.select(&:expresses_unit?)
        end

        def consigned
          commodity.consigned?
        end

        def footnote_ids
          footnotes.map(&:footnote_id)
        end

        def import_measure_ids
          import_measures.map(&:measure_sid)
        end

        def export_measure_ids
          export_measures.map(&:measure_sid)
        end

        def heading_id
          commodity.heading.goods_nomenclature_sid
        end

        def chapter_id
          commodity.chapter.goods_nomenclature_sid
        end

        def ancestor_ids
          commodity.ancestors.pluck(:goods_nomenclature_sid)
        end

        def meursing_code?
          import_measures.any?(&:meursing?)
        end
        alias_method :meursing_code, :meursing_code?

        def zero_mfn_duty?
          third_country_measures.size.positive? && third_country_measures.all?(&:zero_mfn?)
        end

        def third_country_measures
          import_measures.select(&:third_country?)
        end

        def trade_remedies?
          import_measures.any?(&:trade_remedy?)
        end

        def entry_price_system?
          return false if TradeTariffBackend.uk?

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
