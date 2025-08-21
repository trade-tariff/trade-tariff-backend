class DeltaReportService
  def self.generate(date: Time.zone.today)
    new(date).generate_report
  end

  attr_reader :commodity_change_records, :date

  def initialize(date)
    @date = date
    @changes = {}
  end

  def generate_report
    TimeMachine.now do
      collect_all_changes
      generate_commodity_change_records
    end

    ExcelGenerator.call(commodity_change_records, date)

    {
      date: date,
      total_records: @commodity_change_records.size,
      commodity_changes: @commodity_change_records,
    }
  end

  private

  attr_reader :changes

  def collect_all_changes
    @changes[:goods_nomenclatures] = CommodityChanges.collect(date)
    @changes[:measures] = MeasureChanges.collect(date)
    @changes[:measure_components] = MeasureComponentChanges.collect(date)
    @changes[:measure_conditions] = MeasureConditionChanges.collect(date)
    @changes[:geographical_areas] = GeographicalAreaChanges.collect(date)
    @changes[:certificates] = CertificateChanges.collect(date)
    @changes[:additional_codes] = AdditionalCodeChanges.collect(date)
  end

  def generate_commodity_change_records
    @commodity_change_records = []

    @changes.values.flatten.compact.each do |change|
      affected_goods = find_affected_declarable_goods(change)

      affected_goods.each do |commodity|
        @commodity_change_records << {
          type: change[:type],
          operation_date: date,
          chapter: commodity.chapter_short_code,
          commodity_code: commodity.goods_nomenclature_item_id,
          commodity_code_description: commodity.goods_nomenclature_description.description,
          import_export: change[:import_export],
          geo_area: change[:geo_area],
          additional_code: change[:additional_code],
          duty_expression: change[:duty_expression],
          measure_type: change[:measure_type],
          type_of_change: change[:description],
          date_of_effect: change[:date_of_effect],
          change: change[:change],
        }
      end
    end

    @commodity_change_records.uniq!
    @commodity_change_records.sort_by! { |record| record[:commodity_code] }
  end

  def find_affected_declarable_goods(change)
    case change[:type]
    when 'Measure', 'GoodsNomenclature'
      find_declarable_goods_for(change)
    when 'MeasureComponent', 'MeasureCondition'
      find_declarable_goods_for_measure_association(change)
    when 'GeographicalArea'
      find_declarable_goods_for_geographical_area(change)
    when 'Certificate'
      find_declarable_goods_for_certificate(change)
    when 'AdditionalCode'
      find_declarable_goods_for_additional_code(change)
    else
      []
    end
  end

  def find_declarable_goods_for(change)
    if change[:goods_nomenclature_item_id]
      find_declarable_goods_under_code(change[:goods_nomenclature_item_id])
    else
      []
    end
  end

  def find_declarable_goods_for_measure_association(change)
    measure = Sequel::Model.db[:measures]
      .where(measure_sid: change[:measure_sid])
      .first

    if measure
      find_declarable_goods_under_code(measure[:goods_nomenclature_item_id])
    else
      []
    end
  end

  def find_declarable_goods_for_geographical_area(change)
    measures = Sequel::Model.db[:measures]
      .where(geographical_area_id: change[:geographical_area_id])
      .where(operation_date: date)
      .distinct(:goods_nomenclature_item_id)

    measures.map { |m| find_declarable_goods_under_code(m[:goods_nomenclature_item_id]) }
           .flatten
           .uniq
  end

  def find_declarable_goods_for_certificate(change)
    conditions = Sequel::Model.db[:measure_conditions]
      .where(certificate_type_code: change[:certificate_type_code])
      .where(certificate_code: change[:certificate_code])
      .distinct(:measure_sid)

    affected_goods = []
    conditions.each do |condition|
      measure = Sequel::Model.db[:measures]
        .where(measure_sid: condition[:measure_sid])
        .first

      if measure
        affected_goods += find_declarable_goods_under_code(measure[:goods_nomenclature_item_id])
      end
    end

    affected_goods.uniq
  end

  def find_declarable_goods_for_additional_code(change)
    measures = Sequel::Model.db[:measures]
      .where(additional_code_sid: change[:additional_code_sid])
      .where(operation_date: date)
      .distinct(:goods_nomenclature_item_id)

    measures.map { |m| find_declarable_goods_under_code(m[:goods_nomenclature_item_id]) }
           .flatten
           .uniq
  end

  def find_declarable_goods_under_code(goods_nomenclature_item_id)
    return [] unless goods_nomenclature_item_id

    gn = GoodsNomenclature.actual
      .where(goods_nomenclature_item_id: goods_nomenclature_item_id)
      .first

    return [] unless gn

    if gn&.declarable?
      [gn]
    else
      gn.descendants.select(&:declarable?)
    end
  end
end

# Example usage:
#
# Generate report for specific date
# report = DeltaReportService.generate(date: Date.new(2024, 8, 11))
