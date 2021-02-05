class ChemicalSearchService
  include CustomRegex

  attr_reader :cas, :name
  attr_reader :current_page, :per_page, :pagination_record_count

  def initialize(attributes, current_page, per_page)
    @cas = attributes['cas']
    @name = attributes['name']
    @current_page = current_page
    @per_page = per_page
    @pagination_record_count = 0
  end

  def perform
    fetch_by_cas || fetch_by_name
  end

  private

  def fetch_by_cas
    return unless cas = cas_cleaned

    @chemicals = Rails.cache.fetch(cache_id, expires_in: cache_expiry) do
      Chemical.where(Sequel.like(:cas, "%#{cas}%")).all
    end
    Rails.cache.delete(cache_id) unless @chemicals.present?
    custom_paginator(@chemicals)
  end

  def fetch_by_name
    return unless name

    @chemicals = Rails.cache.fetch(cache_id, expires_in: cache_expiry) do
      ChemicalName.where(Sequel.like(:name, "%#{name}%")).map(&:chemical).uniq
    end
    Rails.cache.delete(cache_id) unless @chemicals.present?
    custom_paginator(@chemicals)
  end

  def custom_paginator(result)
    start = (current_page - 1) * per_page
    finish = start + per_page
    @pagination_record_count = result.count

    result.to_a[start..finish] || []
  end

  def result_count(result)
    @pagination_record_count = result.count
    result
  end

  def cache_id
    "chemical-search-#{(cas_cleaned.presence || name.presence)}"
  end

  def cache_expiry(seconds = nil)
    seconds || 24.hours
  end

  def cas_cleaned
    return unless @cas

    if m = cas_number_regex.match(@cas)
      m[2]
    end
  end
end
