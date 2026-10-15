Sequel.migration do # rubocop:disable Metrics/BlockLength
  if TradeTariffBackend.xi?
    filename = '20261015143000_replay_missed_xi_nomenclature_deletes'
    operation_date = Date.new(2026, 10, 15)

    # TARIC created and deleted these SIDs in the same file. The old importer
    # missed the nomenclature deletes because its materialized view was stale.
    # Their indents and descriptions were deleted correctly. Do not restore them.
    # Columns: SID, code, suffix, validity start, source file date.
    deletions = [
      [110_252, '2106108070', '10', '2025-08-29', '2025-06-23'], # TGB25174, record 115
      [110_518, '7212600020', '10', '2026-01-17', '2026-01-11'], # TGB26011, record 386
      [110_523, '7212600020', '80', '2026-01-17', '2026-01-11'], # TGB26011, record 380
      [110_543, '2904990075', '80', '2026-07-01', '2026-02-02'], # TGB26033, record 8
      [110_673, '8708509192', '80', '2026-02-27', '2026-02-11'], # TGB26042, record 118
      [110_720, '7307191035', '20', '2023-01-20', '2026-03-29'], # TGB26088, record 26
      [110_721, '7307191049', '80', '2023-01-20', '2026-03-29'], # TGB26088, record 34
      [110_764, '9705100042', '20', '2026-06-11', '2026-04-24'], # TGB26114, record 1443
      [110_772, '7212506998', '80', '2026-01-01', '2026-04-27'], # TGB26117, record 27
    ]

    up do
      deletions.each do |sid, code, suffix, validity_start, source_date|
        # Read the oplog, not the materialized view, so reruns see our delete.
        latest = GoodsNomenclature::Operation.where(goods_nomenclature_sid: sid)
                                            .order(Sequel.desc(:oid)).first
        next unless latest&.operation == Sequel::Plugins::Oplog::CREATE_OPERATION
        next unless latest.goods_nomenclature_item_id == code && latest.producline_suffix == suffix
        next unless latest.validity_start_date&.to_date == Date.parse(validity_start)
        next unless latest.operation_date == Date.parse(source_date) && latest.validity_end_date.nil?
        next if GoodsNomenclatureIndent.where(goods_nomenclature_sid: sid).any?
        next if GoodsNomenclatureDescription.where(goods_nomenclature_sid: sid).any?

        # Imports can run before the measures view refresh. Find each candidate
        # measure's latest operation before checking its current nomenclature.
        measure_sids = Measure::Operation.where(goods_nomenclature_sid: sid).select(:measure_sid)
        latest_measure_oids = Measure::Operation.where(measure_sid: measure_sids)
                                               .group(:measure_sid).select { max(oid) }
        next if Measure::Operation.where(oid: latest_measure_oids, goods_nomenclature_sid: sid)
                                  .exclude(operation: Sequel::Plugins::Oplog::DESTROY_OPERATION).any?

        values = latest.values.except(:oid)
        values[:filename] = filename
        values[:operation_date] = operation_date
        values[:operation] = Sequel::Plugins::Oplog::DESTROY_OPERATION
        values[:created_at] = GoodsNomenclature::Operation.dataset.current_datetime

        GoodsNomenclature::Operation.insert(values)
      end
    end

    down do
      GoodsNomenclature::Operation.where(
        goods_nomenclature_sid: deletions.map(&:first),
        filename: filename,
        operation_date: operation_date,
        operation: Sequel::Plugins::Oplog::DESTROY_OPERATION,
      ).delete
    end
  end
end
