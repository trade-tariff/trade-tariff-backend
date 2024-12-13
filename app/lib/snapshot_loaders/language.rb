module SnapshotLoaders
  class Language < Base
    def self.load(file, batch)
      languages = []
      descriptions = []

      batch.each do |attributes|
        languages.push({
          language_id: attributes.dig('Language', 'languageId'),
          validity_start_date: attributes.dig('Language', 'validityStartDate'),
          validity_end_date: attributes.dig('Language', 'validityEndDate'),
          operation: attributes.dig('Language', 'metainfo', 'opType'),
          operation_date: attributes.dig('Language', 'metainfo', 'transactionDate'),
          filename: file,
        })

        descriptions.push({
          language_id: attributes.dig('Language', 'languageId'),
          language_code_id: attributes.dig('Language', 'languageDescription', 'language'),
          description: attributes.dig('Language', 'languageDescription', 'description'),
          operation: attributes.dig('Language', 'languageDescription', 'metainfo', 'opType'),
          operation_date: attributes.dig('Language', 'languageDescription', 'metainfo', 'transactionDate'),
          filename: file,
        })
      end

      Object.const_get('Language::Operation').multi_insert(languages)
      Object.const_get('LanguageDescription::Operation').multi_insert(descriptions)
    end
  end
end
