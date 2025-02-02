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
        description = attributes.dig('CertificateType', 'certificateTypeDescription')

        next if description.blank?

        descriptions.push({
          certificate_type_code: attributes['CertificateType']['certificateTypeCode'],
          language_id: description['language']['languageId'],
          description: description['description'],
          operation: description['metainfo']['opType'],
          operation_date: description['metainfo']['transactionDate'],
          filename: file,
        })
      end

      Object.const_get('CertificateType::Operation').multi_insert(certificate_types)
      Object.const_get('CertificateTypeDescription::Operation').multi_insert(descriptions)
    end
  end
end
