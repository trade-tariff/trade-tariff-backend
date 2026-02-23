class CachedCommodityService
  class MeasureMetadataBuilder
    def initialize(presented_commodity)
      @presented_commodity = presented_commodity
    end

    def build
      all_measures.each_with_object({}) do |measure, acc|
        acc[measure.measure_sid] = build_metadata(measure)
      end
    end

    private

    attr_reader :presented_commodity

    def all_measures
      presented_commodity.import_measures + presented_commodity.export_measures
    end

    def build_metadata(measure)
      {
        # Filter fields (for relevant_for_country?)
        geographical_area_id: measure.geographical_area_id,
        erga_omnes: measure.erga_omnes?,
        national: measure.national?,
        meursing_type: measure.measure_type.meursing?,
        excluded_geographical_area_ids: excluded_area_ids(measure),
        contained_geographical_area_ids: contained_area_ids(measure),

        # Classification
        import: measure.import,
        export: measure.export,

        # Commodity-level recomputation
        third_country: measure.third_country?,
        zero_mfn: measure.zero_mfn?,
        formatted_duty_expression: measure.formatted_duty_expression,
        trade_remedy: measure.trade_remedy?,
        entry_price_system: measure.entry_price_system?,
        meursing: measure.meursing?,
        vat: measure.vat?,
        expresses_unit: measure.expresses_unit?,
        tariff_preference: measure.tariff_preference?,
        preferential_quota: measure.preferential_quota?,

        # Preference code inputs
        measure_type_id: measure.measure_type_id,
        authorised_use: measure.authorised_use?,
        special_nature: measure.special_nature?,
        authorised_use_provisions_submission: measure.authorised_use_provisions_submission?,
        gsp_or_dcts: measure.gsp_or_dcts?,

        # Pre-computed contributions
        additional_code_contribution: additional_code_contribution(measure),
        has_no_additional_code: measure.additional_code.blank?,
        measure_unit_contributions: measure_unit_contributions(measure),
        vat_option_contribution: vat_option_contribution(measure),
      }
    end

    def excluded_area_ids(measure)
      measure.excluded_geographical_areas
        .map(&:referenced_or_self)
        .uniq
        .flat_map(&:candidate_excluded_geographical_area_ids)
        .uniq
    end

    def contained_area_ids(measure)
      ga = measure.geographical_area
      return [] if ga.blank?

      (ga.referenced.presence || ga).contained_geographical_areas.pluck(:geographical_area_id)
    end

    def additional_code_contribution(measure)
      return nil unless measure.additional_code&.applicable?

      additional_code = measure.additional_code
      overriding_annotation = AdditionalCode.override_for(additional_code.code)

      code_annotation = if overriding_annotation.present?
                          overriding_annotation.merge(
                            'geographical_area_id' => measure.geographical_area_id,
                            'measure_sid' => measure.measure_sid,
                          )
                        else
                          {
                            'code' => additional_code.code,
                            'overlay' => additional_code.description,
                            'hint' => '',
                            'geographical_area_id' => measure.geographical_area_id,
                            'measure_sid' => measure.measure_sid,
                          }
                        end

      {
        measure_type_id: measure.measure_type_id,
        measure_type_description: measure.measure_type&.description,
        heading: AdditionalCode.heading_for(additional_code.type),
        code_annotation: code_annotation,
      }
    end

    def measure_unit_contributions(measure)
      return nil unless measure.expresses_unit?

      measure.units.map do |unit|
        {
          measurement_unit_code: unit[:measurement_unit_code],
          measurement_unit_qualifier_code: unit[:measurement_unit_qualifier_code],
        }
      end
    end

    def vat_option_contribution(measure)
      return nil unless measure.vat?

      vat_key = if measure.additional_code.present?
                  "#{measure.additional_code.additional_code_type_id}#{measure.additional_code.additional_code}"
                else
                  'VAT'
                end

      vat_duty_amount = measure.measure_components.first&.duty_amount
      vat_description = if measure.additional_code_id.present?
                          measure.additional_code.description
                        else
                          measure.measure_type.description
                        end
      vat_description = "#{vat_description} (#{vat_duty_amount}%)" if measure.additional_code.blank?

      { key: vat_key, description: vat_description }
    end
  end
end
