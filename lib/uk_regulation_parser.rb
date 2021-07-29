class UkRegulationParser
  DELIMITER = "\xC2\xA0".freeze

  def initialize(information_text)
    @original_text = information_text
  end

  def regulation_code
    parsed[1]
  end

  def regulation_url
    parsed[2]
  end

  def description
    parsed[0]
  end

private

  def parsed
    @parsed ||= @original_text.split(DELIMITER)
  end
end
