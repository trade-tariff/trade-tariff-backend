TradeTariffBackend::DataMigrator.migration do
  name "Add missing VTS measure for commodity '7225 9900 40'"

  def apply_at
    TariffSynchronizer::BaseUpdate.latest_applied_of_both_kinds
                                  .first
                                  .applied_at
                                  .strftime("%d.%m.%Y")
  end

  def missing_vat_measures
    [
      [ "7225990040", "VT S", apply_at ]
    ]
  end

  up do
    applicable {
      false # helper_klass.up_applicable?(missing_vat_measures)
    }

    apply {
      helper_klass.up_apply(missing_vat_measures)
    }
  end

  down do
    applicable {
      false # helper_klass.down_applicable?(missing_vat_measures)
    }

    apply {
      helper_klass.down_apply(missing_vat_measures)
    }
  end

  def helper_klass
    ::TradeTariffBackend::DataMigration::Helpers::VatMeasures::ManualAddition
  end
end
