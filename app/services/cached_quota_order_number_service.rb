class CachedQuotaOrderNumberService
  DEFAULT_INCLUDES = [:quota_definition, 'quota_definition.measures'].freeze

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
    QuotaOrderNumber.with_quota_definitions
  end

  def cache_key
    "_quota-order-numbers-#{actual_date}"
  end

  def actual_date
    QuotaOrderNumber.point_in_time&.to_date&.iso8601
  end
end
