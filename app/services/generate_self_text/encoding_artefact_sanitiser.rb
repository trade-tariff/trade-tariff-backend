module GenerateSelfText
  class EncodingArtefactSanitiser
    # AI models occasionally render Unicode code points as literal hex.
    # Longer patterns must precede shorter ones that overlap (a0b0C before b0C).
    ARTEFACTS = {
      # e-acute (U+00E9) - two variant manglings
      'pur0e9e' => 'puree',
      'pure9e' => 'puree',
      'ne9glige9s' => 'negliges',
      'Penede9s' => 'Penedes',
      # e-grave (U+00E8)
      'Gruye8re' => 'Gruyere',
      # a-tilde (U+00E3)
      'De3o' => 'Dao',
      # NBSP (U+00A0) + degree (U+00B0) - must precede b0C
      'a0b0C' => " \u00B0C",
      # NBSP (U+00A0) before units
      'a0mm' => ' mm',
      'a0kg' => ' kg',
      # degree sign (U+00B0)
      'b0C' => "\u00B0C",
      # micro sign (U+00B5)
      'b5m' => "\u00B5m",
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
