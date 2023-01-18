class MeasureCollection < SimpleDelegator
  delegate :new, to: :class

  def initialize(measures, filters = {})
    @measures = measures
    @filters = filters

    super @measures
  end

  def filter
    apply_excise_filter
      .apply_country_filter
  end

  def apply_excise_filter
    if TradeTariffBackend.xi?
      new(@measures.reject(&:excise?), @filters)
    else
      new(@measures, @filters)
    end
  end

  def apply_country_filter
    measures = if filtering_by_country?
                 @measures.select do |measure|
                   measure.relevant_for_country?(filtering_country.geographical_area_id)
                 end
               else
                 @measures
               end

    new(measures, @filters)
  end

  def filtering_by_country?
    @filters[:geographical_area_id].present?
  end

  private

  def filtering_country
    @filtering_country ||= GeographicalArea.find(geographical_area_id: @filters[:geographical_area_id])
  end
end
