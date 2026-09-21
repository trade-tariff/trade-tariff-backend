Sequel.migration do
  # IMPORTANT! Data migrations up block should be idempotent (reruns of up should produce the same effect)
  # they may get re-run as part of data rollbacks but the rollback (down) function of the data migration will not get invoked
  up do
    # Compressed note versions are no longer written or consumed. Delete the
    # rows to free space, mostly in the uk schema where the data lives.
    if TradeTariffBackend.uk?
      Version.where(item_type: 'TariffKnowledge::CompressedNote').delete
    end
  end

  down do
    # Not implemented
  end
end
