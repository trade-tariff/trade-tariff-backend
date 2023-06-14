class BulkSearch
  class ResultCollection
    attr_accessor :status
    attr_reader :id, :searches

    def initialize(data = {})
      @id = data.delete(:id)
      @status = data.delete(:status)
      @searches = (data.delete(:searches) || []).map do |search|
        attributes = search.to_h.try(:deep_symbolize_keys!) || search.to_h

        BulkSearch::Search.new(
          attributes[:input_description],
          attributes[:search_result_ancestors].presence || [],
        )
      end
    end

    def self.build(searches = [])
      data = {}
      id = SecureRandom.uuid
      searches = searches.map do |search|
        search[:attributes]
      end

      data[:id] = id
      data[:status] = BulkSearch::INITIAL_STATE
      data[:searches] = searches

      new(data)
    end

    def as_json(_options = {})
      {
        id:,
        status:,
        searches: searches.map do |search|
          {
            input_description: search.input_description,
            search_result_ancestors: search.search_result_ancestors.map do |search_result_ancestor|
              {
                short_code: search_result_ancestor.short_code,
                goods_nomenclature_item_id: search_result_ancestor.goods_nomenclature_item_id,
                description: search_result_ancestor.description,
                producline_suffix: search_result_ancestor.producline_suffix,
                goods_nomenclature_class: search_result_ancestor.goods_nomenclature_class,
                declarable: search_result_ancestor.declarable,
                score: search_result_ancestor.score,
                reason: search_result_ancestor.reason,
              }
            end,
          }
        end,
      }
    end

    def search_ids
      searches.map(&:id)
    end

    def message
      STATE_MESSAGES[status.to_sym]
    end

    def http_code
      HTTP_CODES[status.to_sym]
    end

    def cannot_proceed?
      status == NOT_FOUND_STATE || status == FAILED_STATE
    end
  end
end
