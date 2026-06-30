# frozen_string_literal: true

Sequel.migration do
  # IMPORTANT! Data migrations up block should be idempotent (reruns of up should produce the same effect)
  # they may get re-run as part of data rollbacks but the rollback (down) function of the data migration will not get invoked

  up do
    next unless TradeTariffBackend.uk?

    operation_dates = TariffChange
      .exclude(operation_date: nil)
      .select(:operation_date)
      .distinct
      .order(:operation_date)
      .map(:operation_date)

    Rails.logger.info("Backfilling missing Commodity start/end changes for #{operation_dates.count} operation dates")

    operation_dates.each do |operation_date|
      transition_changes = TimeMachine.at(operation_date) do
        TariffChangesService.new(operation_date).parent_declarability_transition_changes.select do |change|
          change[:type] == 'Commodity' && [TariffChangesService::BaseChanges::CREATION, TariffChangesService::BaseChanges::ENDING].include?(change[:action])
        end
      end

      existing_keys = TariffChange
        .on_date(operation_date)
        .commodities
        .where(action: [TariffChangesService::BaseChanges::CREATION, TariffChangesService::BaseChanges::ENDING])
        .select(:goods_nomenclature_sid, :action, :date_of_effect)
        .all
        .to_h { |row| [[row.goods_nomenclature_sid, row.action, row.date_of_effect], true] }

      inserted = 0
      skipped = 0

      Sequel::Model.db.transaction do
        transition_changes.each do |change|
          key = [change[:goods_nomenclature_sid], change[:action], change[:date_of_effect]]

          if existing_keys[key]
            skipped += 1
            next
          end

          TariffChange.create(
            type: change[:type],
            object_sid: change[:object_sid],
            goods_nomenclature_item_id: change[:goods_nomenclature_item_id],
            goods_nomenclature_sid: change[:goods_nomenclature_sid],
            action: change[:action],
            operation_date: operation_date,
            date_of_effect: change[:date_of_effect],
            validity_start_date: change[:validity_start_date],
            validity_end_date: change[:validity_end_date],
          )

          existing_keys[key] = true
          inserted += 1
        end
      end

      Rails.logger.info(
        "Backfill for #{operation_date}: expected=#{transition_changes.count} inserted=#{inserted} skipped=#{skipped}",
      )
    end
  end

  down do
    # Irreversible: inserted rows are not tagged, so cannot be safely removed.
  end
end
