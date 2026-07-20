class Measure
  module DatasetFilters
    module OverviewFilters
      def with_seasonal_measures(measure_type_ids, geographical_area_ids)
        start_of_range = Time.zone.today.beginning_of_year
        end_of_range = Time.zone.today.end_of_year + 1.year

        select(
          :measure_sid,
          :goods_nomenclature_item_id,
          :measure_type_id,
          :geographical_area_id,
          :validity_start_date,
          :validity_end_date,
        )
          .where(measure_type_id: measure_type_ids)
          .where(geographical_area_id: geographical_area_ids)
          .exclude(validity_end_date: nil)
          .where('validity_start_date >= ?', start_of_range)
          .where('validity_end_date <= ?', end_of_range)
          .where(Sequel.lit('(validity_end_date::date - validity_start_date::date) NOT IN ?', ANNUAL_DURATION_DAYS))
      end

      def dedupe_similar
        # Needs with_regulation_dates_query and only works within time machine but should be used before not after
        select(Sequel.expr(:measures).*)
          .distinct(:measure_generating_regulation_id,
                    :measure_generating_regulation_role,
                    :measure_type_id,
                    :goods_nomenclature_sid,
                    :geographical_area_id,
                    :geographical_area_sid,
                    :additional_code_type_id,
                    :additional_code_id,
                    :ordernumber)
          .order(*DEDUPE_SORT_ORDER)
      end

      def without_excluded_types
        exclude(measures__measure_type_id: MeasureType.excluded_measure_types)
      end

      def overview
        where do
          overview_types = [
            { measures__measure_type_id: MeasureType::SUPPLEMENTARY_TYPES },
            {
              measures__measure_type_id: MeasureType::THIRD_COUNTRY,
              measures__geographical_area_id: GeographicalArea::ERGA_OMNES_ID,
            },
          ]

          overview_types << if TradeTariffBackend.uk?
                              {
                                measures__measure_type_id: MeasureType::VAT_TYPES,
                                measures__geographical_area_id: GeographicalArea::AREAS_SUBJECT_TO_VAT_OR_EXCISE_ID,
                              }
                            else

                              {
                                measures__measure_type_id: MeasureType::VAT_TYPES,
                                measures__geographical_area_id: GeographicalArea::ERGA_OMNES_ID,
                              }

                            end

          Sequel.|(*overview_types)
        end
      end

      def excluding_licensed_quotas
        exclusion_criteria = Sequel.|(
          *QuotaOrderNumber::LICENSED_QUOTA_PREFIXES.map do |prefix|
            Sequel.like(:ordernumber, "#{prefix}%")
          end,
        )

        exclude(exclusion_criteria)
      end
    end
  end
end
