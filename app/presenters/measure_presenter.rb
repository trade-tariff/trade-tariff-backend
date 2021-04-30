class MeasurePresenter
  HIDDEN_MEASURE_TYPE_IDS = %w[430 447].freeze

  def initialize(collection, declarable)
    @collection = collection
    @declarable = declarable
  end

  def validate!
    @collection = measure_deduplicate
  end

  private

  def measure_deduplicate
    delete_duplicate_third_country_measures
    delete_duplicate_vat_measures(type: 'VTZ')
    delete_duplicate_vat_measures(type: 'VTS')

    @collection.delete_if do |m|
      HIDDEN_MEASURE_TYPE_IDS.include?(m.measure_type_id)
    end

    @collection.compact
  end

  def method_missing(*args, &block)
    @collection.send(*args, &block)
  end

  def delete_duplicate_third_country_measures
    third_country_measures = @collection.select(&:third_country?)

    measures_with_codes = third_country_measures.select(&:additional_code)
    measures_without_codes = third_country_measures.reject(&:additional_code)

    # Deduplicate measures
    measures_with_codes = measures_with_codes.uniq(&:measure_sid)
    measures_without_codes.delete_if { |m| m.goods_nomenclature_sid != @declarable.goods_nomenclature_sid? } if measures_without_codes.size > 1
    @collection.delete_if(&:third_country?)
    @collection.concat(measures_with_codes)
    @collection.concat(measures_without_codes)
  end

  def delete_duplicate_vat_measures(type:)
    return unless @collection.select { |m| m.measure_type_id == type }.any?

    @collection.delete_if { |m| m.measure_type_id == type && m.goods_nomenclature_sid != @declarable.goods_nomenclature_sid }
    latest = @collection.select { |m| m.measure_type_id == type }.sort_by(&:effective_start_date).pop
    @collection.delete_if { |m| m.measure_type_id == type && matching_item_id(m) }
    @collection.prepend(latest) unless @collection.include?(latest)
    @collection
  end

  def matching_item_id(measure)
    measure.goods_nomenclature_item_id == @declarable.goods_nomenclature_item_id
  end
end
