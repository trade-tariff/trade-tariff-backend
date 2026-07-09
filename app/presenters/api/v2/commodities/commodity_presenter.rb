module Api
  module V2
    module Commodities
      class CommodityPresenter < SimpleDelegator
        include SpecialNature

        attr_reader :commodity,
                    :measures

        delegate :id, to: :import_trade_summary, prefix: true
        delegate :filtering_by_country?, to: :measures

        def initialize(commodity, measures)
          super(commodity)
          @commodity = commodity
          @measures = measures
        end

        def consigned
          commodity.consigned_from.present?
        end

        def footnote_ids
          footnotes.map(&:id)
        end

        def footnotes
          @footnotes ||= commodity.footnotes + commodity.heading.footnotes
        end

        def import_measure_ids
          import_measures.map(&:measure_sid)
        end

        def import_measures
          @import_measures ||= measures.select(&:import).map do |measure|
            Api::V2::Measures::MeasurePresenter.new(measure, self)
          end
        end

        def export_measure_ids
          export_measures.map(&:measure_sid)
        end

        def export_measures
          @export_measures ||= measures.select(&:export).map do |measure|
            Api::V2::Measures::MeasurePresenter.new(measure, self)
          end
        end

        def heading_id
          commodity.heading.goods_nomenclature_sid
        end

        def chapter_id
          commodity.chapter.goods_nomenclature_sid
        end

        def ancestors
          @ancestors ||= super.select { |ancestor| ancestor.is_a? TenDigitGoodsNomenclature }
        end

        def ancestor_ids
          ancestors.map(&:goods_nomenclature_sid)
        end

        def meursing_code?
          import_measures.any?(&:meursing?)
        end
        alias_method :meursing_code, :meursing_code?

        def zero_mfn_duty?
          third_country_measures.size.positive? && third_country_measures.all?(&:zero_mfn?)
        end

        def basic_duty_rate
          if third_country_measures.one?
            third_country_measures.first&.formatted_duty_expression
          end
        end

        def third_country_measures
          @third_country_measures ||= import_measures.select(&:third_country?)
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

        def unit_measures
          @unit_measures ||= import_measures.select(&:expresses_unit?)
        end

        def applicable_vat_options
          ApplicableVatOptionsService.new(import_measures).call
        end

        def import_trade_summary
          ImportTradeSummary.build(import_measures)
        end

        def authorised_use_provisions_submission?
          @authorised_use_provisions_submission ||=
            filtering_by_country? && import_measures.any?(&:authorised_use_provisions_submission?)
        end
      end
    end
  end
end
