class DeltaReportService
  def self.generate(start_date: Time.zone.today, end_date: nil)
    new(start_date, end_date || start_date).generate_report
  end

  attr_reader :commodity_change_records, :start_date, :end_date, :date

  def initialize(start_date, end_date)
    @commodity_change_records = []
    @start_date = start_date
    @end_date = end_date
    @changes = {}
  end

  def generate_report
    start_date.upto(end_date).map do |date|
      @date = date
      Rails.logger.info "Processing changes for #{date}"
      TimeMachine.at(date) do
        collect_all_changes
        @commodity_change_records << generate_commodity_change_records
      end
    end

    dates = if end_date == start_date
              start_date.strftime('%Y_%m_%d')
            else
              "#{start_date.strftime('%Y_%m_%d')}_to_#{end_date.strftime('%Y_%m_%d')}"
            end

    ExcelGenerator.call(commodity_change_records, dates)

    {
      dates: dates,
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
    @changes[:excluded_geographical_areas] = ExcludedGeographicalAreaChanges.collect(date)
    @changes[:footnotes] = FootnoteChanges.collect(date)
    @changes[:footnote_association_measures] = FootnoteAssociationMeasureChanges.collect(date)
    @changes[:footnote_association_goods_nomenclature] = FootnoteAssociationGoodsNomenclatureChanges.collect(date)
  end

  def generate_commodity_change_records
    change_records = []

    @changes.values.flatten.compact.each do |change|
      affected_goods = find_affected_declarable_goods(change)

      affected_goods.each do |commodity|
        change_records << {
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

    change_records.uniq!
    change_records.sort_by! { |record| record[:commodity_code] }
  end

  def find_affected_declarable_goods(change)
    case change[:type]
    when 'Measure', 'GoodsNomenclature', 'FootnoteAssociationGoodsNomenclature'
      find_declarable_goods_for(change)
    when 'MeasureComponent', 'MeasureCondition', 'ExcludedGeographicalArea', 'FootnoteAssociationMeasure'
      find_declarable_goods_for_measure_association(change)
    when 'GeographicalArea'
      find_declarable_goods_for_geographical_area(change)
    when 'Certificate'
      find_declarable_goods_for_certificate(change)
    when 'AdditionalCode'
      find_declarable_goods_for_additional_code(change)
    when 'Footnote'
      find_declarable_goods_for_footnote(change)
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
    conditions = Sequel::Model.db[:measure_conditions_oplog]
      .where(certificate_type_code: change[:certificate_type_code])
      .where(certificate_code: change[:certificate_code])
      .distinct(:measure_sid)

    affected_goods = []
    conditions.each do |condition|
      next if condition[:operation_date] == date

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

  def find_declarable_goods_for_footnote(change)
    footnote = Footnote[oid: change[:footnote_oid]]
    if (measures = footnote&.measures)
      measures.map { |m| find_declarable_goods_for({ goods_nomenclature_item_id: m.goods_nomenclature_item_id }) }
              .flatten
              .uniq
    elsif (gns = footnote&.goods_nomenclatures)
      gns.map { |gn| find_declarable_goods_under_code(gn.goods_nomenclature_item_id) }
         .flatten
         .uniq
    else
      []
    end
  end

  def find_declarable_goods_under_code(goods_nomenclature_item_id)
    return [] unless goods_nomenclature_item_id

    gn = GoodsNomenclature.where(goods_nomenclature_item_id: goods_nomenclature_item_id).first

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
# report = DeltaReportService.generate(start_date: Date.new(2025, 7, 24))
#
# Generate report for range of dates
# report = DeltaReportService.generate(start_date: Date.new(2025, 1, 1), end_date: Date.new(2025, 1, 31))
