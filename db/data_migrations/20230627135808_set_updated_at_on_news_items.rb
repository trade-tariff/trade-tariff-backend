Sequel.migration do
  # IMPORTANT! Data migrations up block should be idempotent (reruns of up should produce the same effect)
  # they may get re-run as part of data rollbacks but the rollback (down) function of the data migration will not get invoked
  up do
    News::Collection.where(updated_at: nil).update(updated_at: :created_at)
    News::Item.where(updated_at: nil).update(updated_at: :created_at)
  end

  down do
    News::Item.where(updated_at: :created_at).update(updated_at: nil)
    News::Collection.where(updated_at: :created_at).update(updated_at: nil)
  end
end
