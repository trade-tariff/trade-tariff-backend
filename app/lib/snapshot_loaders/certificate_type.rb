module SnapshotLoaders
  class CertificateType < Base
    def self.load(file, batch)
      certificate_types = []
      descriptions = []

      batch.each do |attributes|
        certificate_types.push({
          certificate_type_code: attributes['CertificateType']['certificateTypeCode'],
          validity_start_date: attributes['CertificateType']['validityStartDate'],
          operation: attributes['CertificateType']['metainfo']['opType'],
          operation_date: attributes['CertificateType']['metainfo']['transactionDate'],
          filename: file,
        })

        descriptions.push({
          certificate_type_code: attributes['CertificateType']['certificateTypeCode'],
          language_id: attributes['CertificateType']['certificateTypeDescription']['languageId'],
          description: attributes['CertificateType']['certificateTypeDescription']['description'],
          operation: attributes['CertificateType']['certificateTypeDescription']['metainfo']['opType'],
          operation_date: attributes['CertificateType']['certificateTypeDescription']['metainfo']['transactionDate'],
          filename: file,
        })
      end

      Object.const_get('CertificateType::Operation').multi_insert(certificate_types)
      Object.const_get('CertificateTypeDescription::Operation').multi_insert(descriptions)
    end
  end
end
