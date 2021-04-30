class MeasurePresenter
  THIRD_COUNTRY_DUTY_ID = '103'.freeze
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
    third_country_duty_dedup
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

  def third_country_duty_dedup
    # TODO: Fix measures with additional codes that are duplicate
    if @collection.select { |m| m.measure_type_id == THIRD_COUNTRY_DUTY_ID }.size > 1
      @collection.delete_if do |m|
        m.measure_type_id == THIRD_COUNTRY_DUTY_ID && m.additional_code.blank? && m.goods_nomenclature_sid != @declarable.goods_nomenclature_sid
      end.compact!
    end
  end

  def delete_duplicate_vat_measures(type:)
    return unless @collection.select { |m| m.measure_type_id == type }.any?

    @collection.delete_if { |m| m.measure_type_id == type && m.goods_nomenclature_sid != @declarable.goods_nomenclature_sid }
    latest = @collection.select { |m| m.measure_type_id == type }.sort_by(&:effective_start_date).pop
    @collection.delete_if { |m| m.measure_type_id == type && matching_item_id(m) }
    @collection.prepend(latest) unless @collection.include?(latest)
    @collection.compact!
  end

  def matching_item_id(measure)
    measure.goods_nomenclature_item_id == @declarable.goods_nomenclature_item_id
  end
end
