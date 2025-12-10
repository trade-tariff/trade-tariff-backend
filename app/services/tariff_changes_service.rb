# frozen_string_literal: true

# Service to generate TariffChange records for a given date
# This differs from the ChangesTablePopulator in that it collects changes based
# on the operation date rather than the validity_start_date
# It is used for the myott Commodity Watchlist feature
class TariffChangesService
  # Generates TariffChange records for the given date.
  # If no date is provided, it generates for all dates since the last change
  def self.generate(date = nil)
    if date.nil?
      last_change_date = TariffChange.max(:operation_date) || (Time.zone.today - 1.year)
      if last_change_date < Time.zone.today
        populate_backlog(from: last_change_date + 1.day, to: Time.zone.today)
      end
    else
      service = new(date)
      service.all_changes
    end
  end

  def self.populate_backlog(from: Time.zone.today - 1.year, to: Time.zone.today)
    from = from.to_date
    to = to.to_date
    (from..to).each do |day|
      new(day).all_changes
    end
  end

  def self.generate_report_for(date = Time.zone.yesterday, user = nil)
    goods_nomenclature_sids = nil

    if user.present?
      goods_nomenclature_sids = user.target_ids_for_my_commodities
    end

    change_records = TransformRecords.call(date, goods_nomenclature_sids)

    return if change_records.empty?

    ExcelGenerator.call(change_records, date)
  end

  attr_reader :tariff_change_records, :date

  def initialize(date)
    @tariff_change_records = []
    @date = date
    @changes = {}
  end

  def all_changes
    TimeMachine.at(date) do
      @changes[:commodities] = CommodityChanges.collect(date)
      @changes[:commodity_descriptions] = CommodityDescriptionChanges.collect(date)
      @changes[:measures] = MeasureChanges.collect(date)
      generate_commodity_change_records
    end

    Sequel::Model.db.transaction do
      TariffChange.delete_for(operation_date: date)
      Rails.logger.info("Inserting #{tariff_change_records.count} records for #{date}")
      TariffChange.multi_insert(tariff_change_records) if tariff_change_records.any?
    end

    {
      date: date.strftime('%Y_%m_%d'),
      count: tariff_change_records.count,
      changes: tariff_change_records.sort_by { |change| [change[:goods_nomenclature_item_id], change[:type], change[:action]] },
    }
  end

  def generate_commodity_change_records
    @changes[:commodities].each do |change|
      add_change_record(change, change[:goods_nomenclature_item_id], change[:object_sid])
    end

    @changes[:commodity_descriptions].each do |change|
      next if matching_commodity_change?(change[:goods_nomenclature_sid], change[:action])

      add_change_record(change, change[:goods_nomenclature_item_id], change[:goods_nomenclature_sid])
    end

    @changes[:measures].each do |change|
      gn = GoodsNomenclature.where(goods_nomenclature_sid: change[:goods_nomenclature_sid]).first

      declarables = if gn.nil?
                      []
                    elsif gn&.declarable?
                      [gn]
                    else
                      gn.descendants.select(&:declarable?)
                    end

      declarables.each do |declarable|
        next if matching_commodity_change?(declarable.goods_nomenclature_sid, change[:action])

        add_change_record(change, declarable.goods_nomenclature_item_id, declarable.goods_nomenclature_sid)
      end
    end
  end

  def matching_commodity_change?(goods_nomenclature_sid, action)
    @tariff_change_records.any? do |record|
      record[:goods_nomenclature_sid] == goods_nomenclature_sid &&
        record[:type] == 'Commodity' &&
        record[:action] == action
    end
  end

  def add_change_record(change, gn_item_id, gn_sid)
    record = {
      type: change[:type],
      object_sid: change[:object_sid],
      goods_nomenclature_item_id: gn_item_id,
      goods_nomenclature_sid: gn_sid,
      action: change[:action],
      operation_date: date,
      date_of_effect: change[:date_of_effect],
      validity_start_date: change[:validity_start_date],
      validity_end_date: change[:validity_end_date],
    }

    # Add JSONB metadata for measure changes
    if change[:type] == 'Measure' && change[:object_sid]
      record[:metadata] = generate_measure_metadata(change[:object_sid]).to_json
    end

    @tariff_change_records << record
  end

  private

  def generate_measure_metadata(measure_sid)
    operation_record = Measure.operation_klass
                              .where(measure_sid: measure_sid)
                              .exclude(operation: 'D')
                              .order(:oid)
                              .last

    return {} unless operation_record

    measure = operation_record.record_from_oplog
    return {} unless measure

    excluded_areas = measure.measure_excluded_geographical_areas_dataset
                           .select(:excluded_geographical_area)
                           .map(:excluded_geographical_area)
                           .sort

    {
      'measure' => {
        'measure_type_id' => measure.measure_type_id,
        'trade_movement_code' => measure.measure_type.trade_movement_code,
        'geographical_area_id' => measure.geographical_area_id,
        'excluded_geographical_area_ids' => excluded_areas,
      },
    }
  end
end
