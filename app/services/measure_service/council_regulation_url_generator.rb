# Get the CELEX link using instructions here:
# https://eur-lex.europa.eu/content/help/data-reuse/linking.html
# https://eur-lex.europa.eu/content/help/eurlex-content/celex-number.html
module MeasureService
  class CouncilRegulationUrlGenerator
    attr_accessor :target_regulation

    def initialize(target_regulation)
      @target_regulation = target_regulation
    end

    def generate
      regulation_code = target_regulation.regulation_id

      year = regulation_code[1..2]

      # When we get to 2071 assume that we don't care about the 1900's
      # or the EU has a better way to search
      full_year = if year.to_i > 70
                    "19#{year}"
                  else
                    "20#{year}"
                  end

      code = "3#{full_year}#{regulation_code.first}#{regulation_code[3..6]}"
      "https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A#{code}"
    end
  end
end
