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

    reject_word = words.one? && (words.first.length < MIN_WORD_LENGTH || stop_words.include?(words.first))

    return '' if reject_word

    words.join(' ')
  end
end
