#
# This service generates search url for http://eur-lex.europa.eu service
#
# We are using 2 approaches of search for regulation details:
#
# APPROACH 1: If regulation have official journal page
#             then we are using seach by Official Journal parameters
#
# APPROACH 2: If regulation doens't have official joirnal page
#             then we are using search by celex number
#

module MeasureService
  class CouncilRegulationUrlGenerator
    attr_accessor :target_regulation

    def initialize(target_regulation)
      @target_regulation = target_regulation
    end

    def generate
      if target_regulation.officialjournal_page.present?
        published_journal_search_type_url
      else
        celex_number_search_type_url
      end
    end

    private

    def published_journal_search_type_url
      oj_seria, oj_number = target_regulation.officialjournal_number
                                             .split(' ')

      oj_page = target_regulation.officialjournal_page
                                 .to_s
                                 .rjust(4, '0')

      url_ops = if target_regulation.is_a?(MeasurePartialTemporaryStop)
                  #
                  # If MeasurePartialTemporaryStop, we do not pass year into the search params
                  # as there are no published_date for partial stop
                  #
                  "whOJ=NO_OJ%3D#{oj_number},PAGE_FIRST%3D#{oj_page}&DB_COLL_OJ=oj-#{oj_seria.downcase}&type=advanced&lang=en"
                else
                  #
                  # If general regulation or FullTemporaryStopRegulation, then
                  # we are providing 'published_date' year to the search parameters
                  #
                  oj_year = target_regulation.published_date.year
                  "whOJ=NO_OJ%3D#{oj_number},YEAR_OJ%3D#{oj_year},PAGE_FIRST%3D#{oj_page}&DB_COLL_OJ=oj-#{oj_seria.downcase}&type=advanced&lang=en"
                end

      "http://eur-lex.europa.eu/search.html?#{url_ops}"
    end

    def celex_number_search_type_url
      regulation_code = regulation_id

      year = regulation_code[1..2]
      # When we get to 2071 assume that we don't care about the 1900's
      # or the EU has a better way to search
      if year.to_i > 70
        full_year = "19#{year}"
      else
        full_year = "20#{year}"
      end

      code = "3#{full_year}#{regulation_code.first}#{regulation_code[3..6]}"
      "http://eur-lex.europa.eu/search.html?instInvStatus=ALL&or0=DN%3D#{code}*,DN-old%3D#{code}*&DTC=false&type=advanced"
    end

    def regulation_id
      target_regulation.regulation_id
    end
  end
end
