module HeadingService
  class HeadingSerializationService
    include DeclarableSerialization

    def initialize(heading, actual_date, filters)
      @heading = heading
      @actual_date = actual_date
      @filters = filters
    end

    def serializable_hash
      heading_cache_key = "heading-#{TradeTariffBackend.service}-#{heading.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}-#{heading.declarable?}"
      if heading.declarable?
        Rails.cache.fetch("_#{heading_cache_key}", expires_in: 24.hours) do
          presenter = Api::V2::Headings::DeclarableHeadingPresenter.new(heading, filtered_measures)
          options = {
            is_collection: false,
            include: DECLARABLE_INCLUDES,
          }
          Api::V2::Headings::DeclarableHeadingSerializer.new(presenter, options).serializable_hash
        end
      else
        Rails.cache.fetch("_#{heading_cache_key}", expires_in: 24.hours) do
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

    private

    attr_reader :heading, :actual_date, :filters

    def filtered_measures
      MeasureCollection.new(measures, filters).filter
    end

    def measures
      heading.measures_dataset.eager(
        {
          geographical_area: [
            :geographical_area_descriptions,
            { contained_geographical_areas: :geographical_area_descriptions },
          ],
        },
        { footnotes: :footnote_descriptions },
        { measure_type: :measure_type_description },
        {
          measure_components: [
            { duty_expression: :duty_expression_description },
            { measurement_unit: :measurement_unit_description },
            :monetary_unit,
            :measurement_unit_qualifier,
          ],
        },
        {
          measure_conditions: [
            { measure_action: :measure_action_description },
            { certificate: :certificate_descriptions },
            { certificate_type: :certificate_type_description },
            { measurement_unit: :measurement_unit_description },
            :monetary_unit,
            :measurement_unit_qualifier,
            { measure_condition_code: :measure_condition_code_description },
            { measure_condition_components: %i[measure_condition
                                               duty_expression
                                               measurement_unit
                                               monetary_unit
                                               measurement_unit_qualifier] },
          ],
        },
        { quota_order_number: :quota_definition },
        { excluded_geographical_areas: :geographical_area_descriptions },
        :additional_code,
        :full_temporary_stop_regulations,
        :measure_partial_temporary_stops,
      ).all
    end
  end
end
