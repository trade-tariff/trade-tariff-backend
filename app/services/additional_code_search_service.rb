class AdditionalCodeSearchService
  attr_reader :code, :type, :description, :as_of
  attr_reader :current_page, :per_page, :pagination_record_count

  def initialize(attributes, current_page, per_page)
    @as_of = AdditionalCode.point_in_time
    @query = [{
      bool: {
        should: [
          # actual date is either between item's (validity_start_date..validity_end_date)
          {
            bool: {
              must: [
                { range: { validity_start_date: { lte: as_of } } },
                { range: { validity_end_date: { gte: as_of } } }
              ]
            }
          },
          # or is greater than item's validity_start_date
          # and item has blank validity_end_date (is unbounded)
          {
            bool: {
              must: [
                { range: { validity_start_date: { lte: as_of } } },
                { bool: { must_not: { exists: { field: 'validity_end_date' } } } }
              ]
            }
          },
          # or item has blank validity_start_date and validity_end_date
          {
            bool: {
              must: [
                { bool: { must_not: { exists: { field: 'validity_start_date' } } } },
                { bool: { must_not: { exists: { field: 'validity_end_date' } } } }
              ]
            }
          }
        ]
      }
    }]

    @code = attributes['code']
    @code = @code[1..-1] if @code&.length == 4
    @type = attributes['type']
    @description = attributes['description']
    @current_page = current_page
    @per_page = per_page
    @pagination_record_count = 0
  end

  def perform
    apply_code_filter if code.present?
    apply_type_filter if type.present?
    apply_description_filter if description.present?
    fetch
    @result
  end

  private

  def fetch
    search_client = ::TradeTariffBackend.cache_client
    index = ::Cache::AdditionalCodeIndex.new(TradeTariffBackend.search_namespace).name
    result = search_client.search index: index, body: { query: { constant_score: { filter: { bool: { must: @query } } } }, size: per_page, from: (current_page - 1) * per_page, sort: %w(additional_code_type_id additional_code) }
    @pagination_record_count = result&.hits&.total&.value || 0
    @result = result&.hits&.hits&.map(&:_source)
  end

  def apply_code_filter
    @query.push({ bool: { must: { term: { additional_code: code } } } })
  end

  def apply_type_filter
    @query.push({ bool: { must: { term: { additional_code_type_id: type } } } })
  end

  def apply_description_filter
    @query.push({ multi_match: { query: description, fields: %w[description], operator: 'and' } })
  end
end
