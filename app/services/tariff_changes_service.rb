# frozen_string_literal: true

# Service to generate TariffChange records for a given date
# This differs from the ChangesTablePopulator in that it collects changes based
# on the operation date rather than the validity_start_date
# It is used for the myott Commodity Watchlist feature
class TariffChangesService
  FALLBACK_START_DATE = Date.new(2024, 12, 31).freeze

  # Generates TariffChange records for the given date.
  # If no date is provided, it generates for all pending changes and all dates since the last change
  def self.generate(date = nil)
    if date.nil?
      TariffChangesJobStatus.pending_changes.each do |pending_date|
        new(pending_date).all_changes
      end

      last_change_date = TariffChangesJobStatus.last_change_date || FALLBACK_START_DATE
      if last_change_date < Time.zone.yesterday
        populate_backlog(from: last_change_date + 1.day, to: Time.zone.yesterday)
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

      # Use individual inserts for proper JSONB handling
      tariff_change_records.each do |record|
        TariffChange.create(record)
      end

      TariffChangesJobStatus.for_date(date).mark_changes_generated!
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

    add_parent_declarability_loss_records

    @changes[:commodity_descriptions].each do |change|
      next if matching_commodity_change?(change[:goods_nomenclature_sid], change[:action])

      add_change_record(change, change[:goods_nomenclature_item_id], change[:goods_nomenclature_sid])
    end

    declarables_by_sid = measure_declarables_by_sid

    @changes[:measures].each do |change|
      declarables_by_sid.fetch(change[:goods_nomenclature_sid], []).each do |declarable|
        next if matching_commodity_change?(declarable.goods_nomenclature_sid, change[:action])

        add_change_record(change, declarable.goods_nomenclature_item_id, declarable.goods_nomenclature_sid)
      end
    end
  end

  def measure_declarables_by_sid
    @measure_declarables_by_sid ||= begin
      goods_nomenclature_sids = @changes[:measures].filter_map { |change| change[:goods_nomenclature_sid] }.uniq

      if goods_nomenclature_sids.empty?
        {}
      else
        goods_nomenclatures = GoodsNomenclature
          .where(goods_nomenclature_sid: goods_nomenclature_sids)
          .eager(:descendants)
          .all
          .index_by(&:goods_nomenclature_sid)

        goods_nomenclature_sids.index_with do |goods_nomenclature_sid|
          declarables_for(goods_nomenclatures[goods_nomenclature_sid])
        end
      end
    end
  end

  def add_parent_declarability_loss_records
    parent_declarability_loss_changes.each do |change|
      next if matching_commodity_change?(change[:goods_nomenclature_sid], change[:action])

      add_change_record(change, change[:goods_nomenclature_item_id], change[:goods_nomenclature_sid])
    end
  end

  def parent_declarability_loss_changes
    created_child_changes = @changes[:commodities]
      .select { |change| change[:action] == BaseChanges::CREATION }
    created_child_changes_by_sid = created_child_changes.index_by { |change| change[:object_sid] }
    created_child_sids = created_child_changes_by_sid.keys.compact.uniq

    return [] if created_child_sids.empty?

    created_children = GoodsNomenclature.where(goods_nomenclature_sid: created_child_sids).eager(:parent).all
    parents = created_children.filter_map(&:parent).uniq(&:goods_nomenclature_sid)
    # Multiple child creations can map to same parent on same run; keep earliest child date_of_effect.
    parent_date_of_effect_by_sid = created_children.each_with_object({}) do |child, dates_by_parent_sid|
      parent = child.parent
      child_change = created_child_changes_by_sid[child.goods_nomenclature_sid]
      next if child_change.nil?

      candidate_date = child_change[:date_of_effect]
      existing_date = dates_by_parent_sid[parent.goods_nomenclature_sid]

      dates_by_parent_sid[parent.goods_nomenclature_sid] =
        if existing_date.nil? || (candidate_date && candidate_date < existing_date)
          candidate_date
        else
          existing_date
        end
    end

    return [] if parents.empty?

    parent_sids = parents.map(&:goods_nomenclature_sid)
    previous_parents_by_sid = TimeMachine.at(date - 1.day) do
      GoodsNomenclature.where(goods_nomenclature_sid: parent_sids).all.index_by(&:goods_nomenclature_sid)
    end

    parents.filter_map do |parent|
      previous_parent = previous_parents_by_sid[parent.goods_nomenclature_sid]

      next unless previous_parent&.declarable?

      {
        type: 'Commodity',
        object_sid: parent.goods_nomenclature_sid,
        goods_nomenclature_item_id: parent.goods_nomenclature_item_id,
        goods_nomenclature_sid: parent.goods_nomenclature_sid,
        action: BaseChanges::ENDING,
        date_of_effect: parent_date_of_effect_by_sid[parent.goods_nomenclature_sid],
        validity_start_date: parent.validity_start_date&.to_date,
        validity_end_date: parent.validity_end_date&.to_date,
      }
    end
  end

  def declarables_for(goods_nomenclature)
    return [] if goods_nomenclature.nil?
    return [goods_nomenclature] if goods_nomenclature.declarable?

    goods_nomenclature.descendants.select(&:declarable?)
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

    if change[:type] == 'Measure' && change[:object_sid]
      record[:metadata] = MeasureMetadataGenerator.call(change[:object_sid])
    end

    @tariff_change_records << record
  end
end
