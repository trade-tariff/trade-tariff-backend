class QuotaPortfolioService
  MAX_PER_PAGE = 100

  # 3rd character of quota_order_number_id is '4' for licensed quotas
  LICENSED_QUOTA_PATTERN = '__4%'.freeze

  attr_reader :filters, :current_page, :per_page

  def initialize(filters:, page:, per_page:)
    @filters = filters
    @current_page = page.to_i.clamp(1, Float::INFINITY)
    @per_page = per_page.to_i.clamp(1, MAX_PER_PAGE)
  end

  def call
    TimeMachine.now do
      base_scope
        .eager(:quota_order_number)
        .order(:quota_order_number_id, :validity_start_date)
        .paginate(current_page, per_page, record_count)
        .all
        .filter_map do |definition|
          order_number = definition.quota_order_number
          next if order_number.nil?

          QuotaUtilizationPresenter.new(order_number, definition, [], Date.current.beginning_of_year, Date.current)
        end
    end
  end

  def record_count
    @record_count ||= TimeMachine.now { base_scope.count }
  end

private

  def base_scope
    scope = QuotaDefinition.actual
    scope = apply_measurement_unit_filter(scope)
    apply_quota_type_filter(scope)
  end

  def apply_measurement_unit_filter(scope)
    code = filters[:measurement_unit_code].presence
    return scope if code.nil?

    scope.where(measurement_unit_code: code.upcase)
  end

  def apply_quota_type_filter(scope)
    case filters[:quota_type].to_s.downcase
    when 'licensed'
      scope.where(Sequel.like(:quota_order_number_id, LICENSED_QUOTA_PATTERN))
    when 'fcfs'
      scope.exclude(Sequel.like(:quota_order_number_id, LICENSED_QUOTA_PATTERN))
    else
      scope
    end
  end
end
