class CachedQuotaOrderNumberService
  DEFAULT_INCLUDES = %w[quota_definition quota_definition.measures].freeze
  EAGER_LOAD = {
    quota_definition: {
      measurement_unit: %i[measurement_unit_description
                           measurement_unit_abbreviations],
      measures: [],
    },
  }.freeze

  TTL = 1.day

  def call
    Rails.cache.fetch(cache_key, expires_in: TTL) do
      Api::V2::QuotaOrderNumbers::QuotaOrderNumberSerializer.new(
        quota_order_numbers,
        include: DEFAULT_INCLUDES,
      ).serializable_hash
    end
  end

  private

  def quota_order_numbers
    QuotaOrderNumber.with_quota_definitions.eager(EAGER_LOAD).all
  end

  def cache_key
    "_quota-order-numbers-#{actual_date}"
  end

  def actual_date
    QuotaOrderNumber.point_in_time&.to_date&.iso8601
  end
end
