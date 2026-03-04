module GenerateSelfText
  class EncodingArtefactSanitiser
    ARTEFACTS = {
      'pure9e' => 'puree',
    }.freeze

    def self.call(text)
      return text if text.blank?

      result = text.dup
      ARTEFACTS.each do |pattern, replacement|
        result.gsub!(pattern, replacement)
      end
      result
    end
  end
end
