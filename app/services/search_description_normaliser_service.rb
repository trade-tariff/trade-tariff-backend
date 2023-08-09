class SearchDescriptionNormaliserService
  delegate :stop_words, to: TradeTariffBackend

  MIN_WORD_LENGTH = 3

  def initialize(description)
    @description = description
  end

  def call
    words = @description
      .to_s
      .downcase
      .scan(/\w+/)

    # Reject stop words unless part of a word phrase
    words = if words.length > 1
              words
            else
              words.reject { |word| stop_words.include?(word) || word.length < MIN_WORD_LENGTH }
            end

    words
      .join(' ')
      .strip
  end
end
