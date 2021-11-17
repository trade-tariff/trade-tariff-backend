module HeadingService
  class HeadingSerializationService
    attr_reader :heading, :actual_date

    def initialize(heading, actual_date)
      @heading = heading
      @actual_date = actual_date
    end

    def serializable_hash
      heading_cache_key = "heading-#{TradeTariffBackend.service}-#{heading.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}-#{heading.declarable?}"
      if heading.declarable?
        Rails.cache.fetch('_' + heading_cache_key, expires_in: 24.hours) do
          @measures = MeasureCollection.new(heading.measures_dataset.eager({ geographical_area: [:geographical_area_descriptions,
                                                                                                { contained_geographical_areas: :geographical_area_descriptions }] },
                                                                           { footnotes: :footnote_descriptions },
                                                                           { measure_type: :measure_type_description },
                                                                           { measure_components: [{ duty_expression: :duty_expression_description },
                                                                                                  { measurement_unit: :measurement_unit_description },
                                                                                                  :monetary_unit,
                                                                                                  :measurement_unit_qualifier] },
                                                                           { measure_conditions: [{ measure_action: :measure_action_description },
                                                                                                  { certificate: :certificate_descriptions },
                                                                                                  { certificate_type: :certificate_type_description },
                                                                                                  { measurement_unit: :measurement_unit_description },
                                                                                                  :monetary_unit,
                                                                                                  :measurement_unit_qualifier,
                                                                                                  { measure_condition_code: :measure_condition_code_description },
                                                                                                  { measure_condition_components: [:measure_condition,
                                                                                                                                   :duty_expression,
                                                                                                                                   :measurement_unit,
                                                                                                                                   :monetary_unit,
                                                                                                                                   :measurement_unit_qualifier] }] },
                                                                           { quota_order_number: :quota_definition },
                                                                           { excluded_geographical_areas: :geographical_area_descriptions },
                                                                           :additional_code,
                                                                           :full_temporary_stop_regulations,
                                                                           :measure_partial_temporary_stops).all, heading).deduplicate.filter
          presenter = Api::V2::Headings::DeclarableHeadingPresenter.new(heading, @measures)
          options = { is_collection: false }
          options[:include] = [:section,
                               :chapter,
                               'chapter.guides',
                               :footnotes,
                               :import_measures,
                               'import_measures.duty_expression',
                               'import_measures.measure_type',
                               'import_measures.legal_acts',
                               'import_measures.suspending_regulation',
                               'import_measures.measure_conditions',
                               'import_measures.measure_conditions.measure_condition_components',
                               'import_measures.geographical_area',
                               'import_measures.geographical_area.contained_geographical_areas',
                               'import_measures.excluded_geographical_areas',
                               'import_measures.footnotes',
                               'import_measures.additional_code',
                               'import_measures.measure_components',
                               'import_measures.national_measurement_units',
                               'import_measures.order_number',
                               'import_measures.order_number.definition',
                               :export_measures,
                               'export_measures.duty_expression',
                               'export_measures.measure_type',
                               'export_measures.legal_acts',
                               'export_measures.suspending_regulation',
                               'export_measures.measure_conditions',
                               'export_measures.measure_conditions.measure_condition_components',
                               'export_measures.geographical_area',
                               'export_measures.geographical_area.contained_geographical_areas',
                               'export_measures.excluded_geographical_areas',
                               'export_measures.footnotes',
                               'export_measures.additional_code',
                               'export_measures.measure_components',
                               'export_measures.national_measurement_units',
                               'export_measures.order_number',
                               'export_measures.order_number.definition',]
          Api::V2::Headings::DeclarableHeadingSerializer.new(presenter, options).serializable_hash
        end
      else
        Rails.cache.fetch('_' + heading_cache_key, expires_in: 24.hours) do
          service = HeadingService::CachedHeadingService.new(heading, actual_date)
          hash = service.serializable_hash
          options = { is_collection: false }
          options[:include] = [:section,
                               :chapter,
                               'chapter.guides',
                               :footnotes,
                               :commodities,
                               'commodities.overview_measures',
                               'commodities.overview_measures.duty_expression',
                               'commodities.overview_measures.measure_type']
          Api::V2::Headings::HeadingSerializer.new(hash, options).serializable_hash
        end
      end
    end
  end
end
