class UkRegulationParser
  DELIMITER = "\xC2\xA0".freeze
  attr_reader :regulation_code, :regulation_url, :description

  def initialize(information_text)
    @original_text = information_text
    @description, @regulation_code, @regulation_url = parse_information_text
  end

  class NonUkRegulationText < ::RuntimeError; end

private

  def parse_information_text
    @original_text&.split(DELIMITER).tap do |parts|
      raise NonUkRegulationText unless parts&.length == 3
    end
  end
end
