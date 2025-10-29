# frozen_string_literal: true

# Service to generate TariffChange records for a given date
# This differs from the ChangesTablePopulator in that it collects changes based
# on the operation date rather than the validity_start_date
# It is used for the myott Commodity Watchlist feature
class TariffChangesService
  def self.generate(date = Time.zone.today)
    service = new(date)
    service.all_changes
  end

  def self.populate_backlog(from: Time.zone.today - 1.year, to: Time.zone.today)
    from = from.to_date
    to = to.to_date
    (from..to).each do |day|
      new(day).all_changes
    end
  end

  def self.generate_report_for(date)
    change_records = TransformRecords.call(date)
    package = ExcelGenerator.call(change_records, date)

    if Rails.env.development?
      package.serialize("commodity_watchlist_#{date.strftime('%Y_%m_%d')}.xlsx")
    else
      ReportsMailer.commodity_watchlist(date, package).deliver_now
    end
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
    @tariff_change_records << {
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
  end
end
