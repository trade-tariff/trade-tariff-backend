class OverviewMeasurePresenter
  def initialize(collection, declarable)
    @collection = collection
    @declarable = declarable
  end

  def validate!
    @collection = measure_deduplicate
  end

  private

  def measure_deduplicate
    delete_duplicate_vat_measures(type: 'VTZ')
    delete_duplicate_vat_measures(type: 'VTS')

    @collection.compact
  end

  def delete_duplicate_vat_measures(type:)
    return unless @collection.select { |m| m.measure_type_id == type }.any?

    @collection.delete_if { |m| m.measure_type_id == type && m.goods_nomenclature_sid != @declarable.goods_nomenclature_sid }
    latest = @collection.select { |m| m.measure_type_id == type }.sort_by(&:effective_start_date).pop
    @collection.uniq! { |m| m.duty_expression_with_national_measurement_units_for || m.duty_expression.base }
    @collection.delete_if { |m| m.measure_type_id == type && measure.goods_nomenclature_item_id == @declarable.goods_nomenclature_item_id }
    @collection.prepend(latest) unless @collection.include?(latest)
    @collection.compact!
  end
end
