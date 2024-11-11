module Loaders
  class CertificateType < Base
    def self.load(file, attributes)
      Object.const_get('CertificateType::Operation').create({
        certificate_type_code: attributes['CertificateType']['certificateTypeCode'],
        validity_start_date: attributes['CertificateType']['validityStartDate'],
        operation: attributes['CertificateType']['metainfo']['opType'],
        operation_date: attributes['CertificateType']['metainfo']['transactionDate'],
        filename: file,
      })

      Object.const_get('CertificateTypeDescription::Operation').create({
        certificate_type_code: attributes['CertificateType']['certificateTypeCode'],
        language_id: attributes['CertificateType']['certificateTypeDescription']['languageId'],
        description: attributes['CertificateType']['certificateTypeDescription']['description'],
        operation: attributes['CertificateType']['certificateTypeDescription']['metainfo']['opType'],
        operation_date: attributes['CertificateType']['certificateTypeDescription']['metainfo']['transactionDate'],
        filename: file,
      })
    end
  end
end
