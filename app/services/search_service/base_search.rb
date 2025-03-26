class SearchService
  class BaseSearch
    BLANK_RESULT = {
      goods_nomenclature_match: {
        sections: [], chapters: [], headings: [], commodities: []
      },
      reference_match: {
        sections: [], chapters: [], headings: [], commodities: []
      },
    }.freeze

    attr_reader :query_string, :results, :date, :resource_id

    def initialize(query_string, date, resource_id = nil)
      @query_string = query_string.to_s.squish.downcase
      @date = date
      @resource_id = resource_id
    end

    delegate :present?, to: :@results
  end
end
