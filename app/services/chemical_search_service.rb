class ChemicalSearchService
  include CustomRegex

  attr_reader :cas, :name, :current_page, :per_page, :pagination_record_count

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
    cas = cas_cleaned

    return unless cas

    @chemicals = Chemical.where(Sequel.like(:cas, "%#{cas}%")).all
    custom_paginator(@chemicals)
  end

  def fetch_by_name
    return unless name

    @chemicals = ChemicalName.where(Sequel.like(:name, "%#{name}%")).eager(:chemical).all.map(&:chemical).uniq
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

  def cas_cleaned
    return unless @cas

    cas_number_regex.match(@cas.to_s.first(100)).try(:[], 1)
  end
end
