Sequel.migration do # rubocop:disable Metrics/BlockLength
  if TradeTariffBackend.xi?
    filename = '20261016120000_replay_missed_xi_deletes'
    manifest = JSON.parse(Rails.root.join('db/data_migrations/data', "#{filename}.json").read, symbolize_names: true)
    # Column names are shared per model to keep the static manifest small.
    deletions = manifest.flat_map do |group|
      columns = group.fetch(:columns).map(&:to_sym)
      group.fetch(:deletions).map do |deletion|
        deletion.merge(model: group.fetch(:model), attributes: columns.zip(deletion.fetch(:values)).to_h)
      end
    end
    models = deletions.map { |deletion| deletion.fetch(:model).constantize }.uniq

    # The manifest contains explicit TARIC deletes, not missing-view guesses.
    # It excludes later source recreations and the files replayed after 8 May 2026.
    up do
      transaction do
        # Keep an import from inserting a newer operation between our guard and delete.
        locked_models = models + [GoodsNomenclatureIndent, GoodsNomenclatureDescription]
        tables = locked_models.map { |model| literal(model.operation_klass.table_name) }.uniq.sort
        run("LOCK TABLE #{tables.join(', ')} IN SHARE ROW EXCLUSIVE MODE")

        deletions.each do |deletion|
          model = deletion.fetch(:model).constantize
          attributes = deletion.fetch(:attributes)
          key = attributes.slice(*Array(model.primary_key))
          history = model.operation_klass.where(key)
          latest = history.order(Sequel.desc(:oid)).first

          next unless latest&.operation == Sequel::Plugins::Oplog::CREATE_OPERATION
          next unless latest.operation_date == Date.iso8601(deletion.fetch(:create_date)) && latest.filename.nil?
          # The count also protects same-day recreations, even with identical values.
          next unless history.count == deletion.fetch(:expected_operations)
          next unless history.where(oid: latest.oid).where(attributes).any?

          if model == GoodsNomenclature
            # Use each child's latest oplog row, including moves to another SID.
            # A stale view or an expired validity period must not hide a live child.
            live_child = [GoodsNomenclatureIndent, GoodsNomenclatureDescription, Measure].any? do |child|
              primary_key = Array(child.primary_key)
              operations = child.operation_klass
              keys = operations.where(goods_nomenclature_sid: key.fetch(:goods_nomenclature_sid)).select(*primary_key)
              latest_oids = operations.where(primary_key => keys).group(*primary_key).select { max(oid) }
              operations.where(oid: latest_oids, goods_nomenclature_sid: key.fetch(:goods_nomenclature_sid))
                        .exclude(operation: Sequel::Plugins::Oplog::DESTROY_OPERATION).any?
            end
            next if live_child
          end

          values = latest.values.except(:oid).merge(
            filename: filename,
            operation: Sequel::Plugins::Oplog::DESTROY_OPERATION,
            # TARIC rollback uses this date. Keep the repair with the source delete,
            # including the six deletes in the file after their creation file.
            operation_date: Date.iso8601(deletion.fetch(:source_file).first(10)),
            created_at: model.operation_klass.dataset.current_datetime,
          )
          model.operation_klass.insert(values)
        end
      end
    end

    down do
      transaction do
        deletions.each do |deletion|
          model = deletion.fetch(:model).constantize
          key = deletion.fetch(:attributes).slice(*Array(model.primary_key))
          model.operation_klass.where(key).where(
            filename: filename,
            operation: Sequel::Plugins::Oplog::DESTROY_OPERATION,
            operation_date: Date.iso8601(deletion.fetch(:source_file).first(10)),
          ).delete
        end
      end
    end
  end
end
