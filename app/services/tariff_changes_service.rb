class TariffChangesService
  def self.generate(date = Time.zone.today)
    service = new(date)
    service.all_changes
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
      @changes[:measures] = MeasureChanges.collect(date)
      generate_commodity_change_records
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
        next if matching_commodity_change?(declarable, change[:action])

        add_change_record(change, declarable.goods_nomenclature_item_id, declarable.goods_nomenclature_sid)
      end
    end
  end

  def matching_commodity_change?(declarable, action)
    @tariff_change_records.any? do |record|
      record[:goods_nomenclature_sid] == declarable.goods_nomenclature_sid &&
        record[:type] == 'Commodity' &&
        record[:action] == action
    end
  end

  def add_change_record(change, gn_item_id, gn_sid)
    @tariff_change_records << {
      type: change[:type],
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
