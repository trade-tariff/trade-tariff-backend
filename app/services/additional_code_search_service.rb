class AdditionalCodeSearchService
  attr_reader :code, :type, :description, :as_of, :current_page, :per_page, :pagination_record_count

  def initialize(attributes, current_page, per_page)
    @as_of = Time.zone.today.iso8601
    @query = [{
      bool: {
        should: [
          # actual date is either between item's (validity_start_date..validity_end_date)
          {
            bool: {
              must: [
                { range: { validity_start_date: { lte: as_of } } },
                { range: { validity_end_date: { gte: as_of } } },
              ],
            },
          },
          # or is greater than item's validity_start_date
          # and item has blank validity_end_date (is unbounded)
          {
            bool: {
              must: [
                { range: { validity_start_date: { lte: as_of } } },
                { bool: { must_not: { exists: { field: 'validity_end_date' } } } },
              ],
            },
          },
          # or item has blank validity_start_date and validity_end_date
          {
            bool: {
              must: [
                { bool: { must_not: { exists: { field: 'validity_start_date' } } } },
                { bool: { must_not: { exists: { field: 'validity_end_date' } } } },
              ],
            },
          },
        ],
      },
    }]

    @code = attributes['code']
    @code = @code[1..] if @code&.length == 4
    @type = attributes['type']
    @description = attributes['description']
    @current_page = current_page
    @per_page = per_page
    @pagination_record_count = 0
  end

  def call
    apply_code_filter
    apply_type_filter
    apply_description_filter

    fetch
  end

  private

  def fetch
    search_client = ::TradeTariffBackend.cache_client
    index = ::Cache::AdditionalCodeIndex.new.name
    result = search_client.search index:, body: { query: { constant_score: { filter: { bool: { must: @query } } } }, size: per_page, from: (current_page - 1) * per_page, sort: %w[additional_code_type_id additional_code] }
    @pagination_record_count = result&.hits&.total&.value || 0
    @result = result&.hits&.hits&.map(&:_source)
    @result
  end

  def apply_code_filter
    return if code.blank?

    @query.push({ bool: { must: { term: { additional_code: code } } } })
  end

  def apply_type_filter
    return if type.blank?

    @query.push({ bool: { must: { term: { additional_code_type_id: type } } } })
  end

  def apply_description_filter
    return if description.blank?

    @query.push({ multi_match: { query: description, fields: %w[description], operator: 'and' } })
  end
end
