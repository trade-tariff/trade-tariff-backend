TradeTariffBackend::DataMigrator.migration do
  name "Fix National Certificate Type validity period"

  up do
    applicable {
      CertificateType::Operation.where(
        certificate_type_code: '9',
        validity_start_date: Date.new(1971,12,13)
      ).none?
      false
    }

    apply {
      CertificateType::Operation.where(
        certificate_type_code: '9',
      ).update(
        validity_start_date: Date.new(1971,12,13)
      )
    }
  end

  down do
    applicable {
      CertificateType::Operation.where(
        certificate_type_code: '9',
        validity_start_date: nil
      ).none?
      false
    }

    apply {
      CertificateType::Operation.where(
        certificate_type_code: '9',
      ).update(
        validity_start_date: nil
      )
    }
  end
end
