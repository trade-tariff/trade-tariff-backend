module Loaders
  class Certificate < Base
    def self.load(file, batch)
      certificates = []
      periods = []
      descriptions = []

      batch.each do |attributes|
        certificates.push({
                            certificate_code: attributes.dig('Certificate', 'certificateCode'),
                            certificate_type_code: attributes.dig('Certificate', 'certificateType', 'certificateTypeCode'),
                            validity_start_date: attributes.dig('Certificate', 'validityStartDate'),
                            validity_end_date: attributes.dig('Certificate', 'validityEndDate'),
                            operation: attributes.dig('Certificate', 'metainfo', 'opType'),
                            operation_date: attributes.dig('Certificate', 'metainfo', 'transactionDate'),
                            filename: file,
                          })

        period_attributes = if attributes.dig('Certificate', 'certificateDescriptionPeriod').is_a?(Array)
                              attributes.dig('Certificate', 'certificateDescriptionPeriod')
                            else
                              Array.wrap(attributes.dig('Certificate', 'certificateDescriptionPeriod'))
                            end

        period_attributes.each do |period|

          periods.push({
                         certificate_code: attributes.dig('Certificate', 'certificateCode'),
                         certificate_type_code: attributes.dig('Certificate', 'certificateType', 'certificateTypeCode'),
                         certificate_description_period_sid: period.dig('sid'),
                         validity_start_date: period.dig('validityStartDate'),
                         validity_end_date: period.dig('validityEndDate'),
                         operation: period.dig('metainfo', 'opType'),
                         operation_date: period.dig('metainfo', 'transactionDate'),
                         filename: file,
                       })

          description = period.dig('certificateDescription')
          next unless description

          descriptions.push({
                              certificate_code: attributes.dig('Certificate', 'certificateCode'),
                              certificate_type_code: attributes.dig('Certificate', 'certificateType', 'certificateTypeCode'),
                              certificate_description_period_sid: period.dig('sid'),
                              language_id: description.dig('language', 'languageId'),
                              description: description.dig('description'),
                              operation: description.dig('metainfo', 'opType'),
                              operation_date: description.dig('metainfo', 'transactionDate'),
                              filename: file,
                            })
        end
      end

      Object.const_get('Certificate::Operation').multi_insert(certificates)
      Object.const_get('CertificateDescriptionPeriod::Operation').multi_insert(periods)
      Object.const_get('CertificateDescription::Operation').multi_insert(descriptions)
    end
  end
end
