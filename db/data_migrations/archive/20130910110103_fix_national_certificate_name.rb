TradeTariffBackend::DataMigrator.migration do
  name "Fix National Certificate name"

  CERTIFICATE_TEXT_NEW = 'E.Certificates of origin for steel'
  CERTIFICATE_TEXT_OLD = 'E.certificates_oplog of origin for steel'

  up do
    applicable {
      CertificateDescription::Operation.where(
        certificate_type_code: '9',
        certificate_code: '004',
        description: CERTIFICATE_TEXT_NEW
      ).none?
      false
    }

    apply {
      CertificateDescription::Operation.where(
        certificate_type_code: '9',
        certificate_code: '004',
      ).update(
        description: CERTIFICATE_TEXT_NEW
      )
    }
  end

  down do
    applicable {
      CertificateDescription::Operation.where(
        certificate_type_code: '9',
        certificate_code: '004',
        description: CERTIFICATE_TEXT_OLD
      ).none?
      false
    }

    apply {
      CertificateDescription::Operation.where(
        certificate_type_code: '9',
        certificate_code: '004',
      ).update(
        description: CERTIFICATE_TEXT_OLD
      )
    }
  end
end
