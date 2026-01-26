class SearchService
  class BaseSearch
    BLANK_RESULT = {
      goods_nomenclature_match: {
        chapters: [], headings: [], commodities: []
      },
      reference_match: {
        chapters: [], headings: [], commodities: []
      },
    }.freeze

    attr_reader :query_string, :results, :date, :resource_id

    def initialize(query_string, resource_id = nil)
      @query_string = query_string.to_s.squish.downcase
      @date = TradeTariffRequest.time_machine_now
      @resource_id = resource_id
    end

    delegate :present?, to: :@results
  end
end
