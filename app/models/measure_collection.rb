class MeasureCollection < SimpleDelegator
  THIRD_COUNTRY_DUTY_ID = '103'.freeze
  HIDDEN_MEASURE_TYPE_IDS = %w[430 447].freeze

  attr_reader :declarable, :measures

  def initialize(measures, declarable)
    @measures = measures
    @declarable = declarable

    super(measures)
  end

  def deduplicate
    self.class.new(measure_deduplicate, declarable)
  end

  def filter
    self.class.new(filter_out_excise_measures, declarable)
  end

  private

  def measure_deduplicate
    third_country_duty_dedup
    delete_duplicate_vat_measures(type: 'VTZ')
    delete_duplicate_vat_measures(type: 'VTS')

    delete_if do |measure|
      HIDDEN_MEASURE_TYPE_IDS.include?(measure.measure_type_id)
    end

    compact
  end

  def third_country_duty_dedup
    # TODO: Fix measures with additional codes that are duplicate
    if select { |measure| measure.measure_type_id == THIRD_COUNTRY_DUTY_ID }.size > 1
      delete_if { |measure|
        measure.measure_type_id == THIRD_COUNTRY_DUTY_ID && measure.additional_code.blank? && measure.goods_nomenclature_sid != @declarable.goods_nomenclature_sid
      }.compact!
    end
  end

  def delete_duplicate_vat_measures(type:)
    return unless select { |measure| measure.measure_type_id == type }.any?

    delete_if { |measure| measure.measure_type_id == type && measure.goods_nomenclature_sid != @declarable.goods_nomenclature_sid }
    latest = select { |measure| measure.measure_type_id == type }.sort_by(&:effective_start_date).pop
    delete_if { |measure| measure.measure_type_id == type && matching_item_id(measure) }
    prepend(latest) unless include?(latest)
    compact!
  end

  def matching_item_id(measure)
    measure.goods_nomenclature_item_id == @declarable.goods_nomenclature_item_id
  end

  def filter_out_excise_measures
    if TradeTariffBackend.xi?
      reject(&:excise?)
    else
      @measures
    end
  end
end
