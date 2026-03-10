Sequel.migration do
  up do
    now = Time.now

    # Step 1: Backfill "create" versions for all existing records.
    # This captures a baseline snapshot for version history.
    models = {
      'GoodsNomenclatureLabel' => { table: :goods_nomenclature_labels, pk: :goods_nomenclature_sid },
      'GoodsNomenclatureSelfText' => { table: :goods_nomenclature_self_texts, pk: :goods_nomenclature_sid },
      'AdminConfiguration' => { table: Sequel[:admin_configurations].qualify(:uk), pk: :name },
      'ChapterNote' => { table: :chapter_notes, pk: :id },
      'SectionNote' => { table: :section_notes, pk: :id },
      'SearchReference' => { table: :search_references, pk: :id },
    }

    models.each do |item_type, config|
      from(config[:table]).each do |record|
        item_id = record[config[:pk]].to_s
        created_at = record[:created_at] || record[:updated_at] || now

        from(:versions).insert(
          item_type: item_type,
          item_id: item_id,
          event: 'create',
          object: Sequel.pg_jsonb_wrap(record.transform_keys(&:to_s)),
          whodunnit: nil,
          created_at: created_at,
        )
      end
    end

    # Step 2: Migrate old audit data for models that previously used plugin :auditable.
    # Old audits store column diffs { "col" => [old_val, new_val] }. We reconstruct
    # full snapshots by starting from the current record state and reversing each diff.
    audit_table = Sequel[:audits].qualify(:uk)

    begin
      audit_count = from(audit_table).count
    rescue Sequel::Error
      audit_count = 0
    end

    next if audit_count.zero?

    auditable_models = {
      'ChapterNote' => { table: :chapter_notes, pk: :id },
      'SectionNote' => { table: :section_notes, pk: :id },
      'SearchReference' => { table: :search_references, pk: :id },
    }

    auditable_models.each do |item_type, config|
      audits_by_record = from(audit_table)
        .where(auditable_type: item_type)
        .order(Sequel.desc(:version))
        .all
        .group_by { |a| a[:auditable_id] }

      audits_by_record.each do |auditable_id, audits|
        record = from(config[:table]).where(config[:pk] => auditable_id).first
        next unless record

        snapshot = record.transform_keys(&:to_s)

        # Process audits newest-first, inserting an "update" version for each,
        # then reversing the diff to reconstruct the previous state.
        audits.each do |audit|
          changes = audit[:changes]
          changes = JSON.parse(changes) if changes.is_a?(String)
          next unless changes.is_a?(Hash)

          from(:versions).insert(
            item_type: item_type,
            item_id: auditable_id.to_s,
            event: 'update',
            object: Sequel.pg_jsonb_wrap(snapshot.dup),
            whodunnit: nil,
            created_at: audit[:created_at],
          )

          changes.each do |col, diff|
            old_val = diff.is_a?(Array) ? diff.first : diff
            snapshot[col.to_s] = old_val
          end
        end

        # After reversing all diffs, snapshot is the initial state.
        # Update the "create" version we inserted in step 1.
        create_version_id = from(:versions)
          .where(item_type: item_type, item_id: auditable_id.to_s, event: 'create')
          .get(:id)

        next unless create_version_id

        from(:versions)
          .where(id: create_version_id)
          .update(object: Sequel.pg_jsonb_wrap(snapshot))
      end
    end
  end

  down do
    from(:versions).delete
  end
end
