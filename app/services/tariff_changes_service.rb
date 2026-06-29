# frozen_string_literal: true

# Service to generate TariffChange records for a given date
# This differs from the ChangesTablePopulator in that it collects changes based
# on the operation date rather than the validity_start_date
# It is used for the myott Commodity Watchlist feature
class TariffChangesService
  FALLBACK_START_DATE = Date.new(2024, 12, 31).freeze

  # Frozen snapshot of a GoodsNomenclature at a specific point in time, used to
  # capture declarability at the correct TimeMachine date.
  ParentSnapshot = Data.define(:goods_nomenclature_sid, :goods_nomenclature_item_id, :validity_start_date, :validity_end_date, :declarable) do
    def declarable? = declarable
  end

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

    add_parent_declarability_transition_records

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

  def add_parent_declarability_transition_records
    parent_declarability_transition_changes.each do |change|
      next if matching_commodity_change?(change[:goods_nomenclature_sid], change[:action])

      add_change_record(change, change[:goods_nomenclature_item_id], change[:goods_nomenclature_sid])
    end
  end

  def parent_declarability_transition_changes
    parent_declarability_child_changes.filter_map { |child_change|
      parent_declarability_transition_for(child_change)
    }.uniq { |change| [change[:goods_nomenclature_sid], change[:action], change[:date_of_effect]] }
  end

  def parent_declarability_child_changes
    @parent_declarability_child_changes ||= GoodsNomenclature.operation_klass
      .where(operation_date: date)
      .filter_map do |op_record|
        next if op_record.record.nil?

        change = TariffChangesService::CommodityChanges.new(op_record.record, date).analyze
        next if change.nil?

        next unless [BaseChanges::CREATION, BaseChanges::ENDING].include?(change[:action])
        next if change[:object_sid].blank? || change[:date_of_effect].blank?

        change
      end
  end

  def parent_declarability_transition_for(child_change)
    child_effective_date = child_change[:date_of_effect]

    before_date, after_date =
      if child_change[:action] == BaseChanges::CREATION
        [child_effective_date - 1.day, child_effective_date]
      else
        [child_effective_date, child_effective_date + 1.day]
      end

    parent = parent_for_child_at(child_change[:object_sid], child_effective_date)
    return if parent.nil?

    previous_parent = goods_nomenclature_at(parent.goods_nomenclature_sid, before_date)
    current_parent = goods_nomenclature_at(parent.goods_nomenclature_sid, after_date)

    previous_declarable = previous_parent&.declarable? || false
    current_declarable = current_parent&.declarable? || false
    return if previous_declarable == current_declarable

    action = previous_declarable ? BaseChanges::ENDING : BaseChanges::CREATION
    date_of_effect = previous_declarable ? before_date : after_date

    {
      type: 'Commodity',
      object_sid: parent.goods_nomenclature_sid,
      goods_nomenclature_item_id: parent.goods_nomenclature_item_id,
      goods_nomenclature_sid: parent.goods_nomenclature_sid,
      action:,
      date_of_effect:,
      validity_start_date: action == BaseChanges::CREATION ? date_of_effect : current_parent&.validity_start_date&.to_date,
      validity_end_date: action == BaseChanges::ENDING ? date_of_effect : current_parent&.validity_end_date&.to_date,
    }
  end

  def parent_for_child_at(child_sid, snapshot_date)
    @parent_for_child_at_cache ||= {}
    cache_key = [child_sid, snapshot_date.to_date]
    return @parent_for_child_at_cache[cache_key] if @parent_for_child_at_cache.key?(cache_key)

    @parent_for_child_at_cache[cache_key] = TimeMachine.at(snapshot_date) do
      GoodsNomenclature.where(goods_nomenclature_sid: child_sid).actual.eager(:parent).first&.parent
    end
  end

  def goods_nomenclature_at(goods_nomenclature_sid, snapshot_date)
    @goods_nomenclature_at_cache ||= {}
    cache_key = [goods_nomenclature_sid, snapshot_date.to_date]
    return @goods_nomenclature_at_cache[cache_key] if @goods_nomenclature_at_cache.key?(cache_key)

    @goods_nomenclature_at_cache[cache_key] = TimeMachine.at(snapshot_date) do
      gn = GoodsNomenclature.where(goods_nomenclature_sid: goods_nomenclature_sid).actual.first
      next nil if gn.nil?

      # Evaluate declarable? here, inside the TimeMachine block, so that
      # leaf? -> children.empty? queries at the correct point-in-time snapshot.
      # Captured in a frozen value object to avoid re-querying outside this block.
      ParentSnapshot.new(
        goods_nomenclature_sid: gn.goods_nomenclature_sid,
        goods_nomenclature_item_id: gn.goods_nomenclature_item_id,
        validity_start_date: gn.validity_start_date,
        validity_end_date: gn.validity_end_date,
        declarable: gn.declarable?,
      )
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
