class QuotaSearchService
  DEFAULT_EAGER_LOAD_GRAPH = {
    quota_order_number: [
      { quota_order_number_origins: [{ geographical_area: :geographical_area_descriptions }] },
    ],
    quota_definition: [
      { measures: [{ geographical_area: :geographical_area_description }] },
      :quota_suspension_periods,
      :quota_blocking_periods,
      {
        quota_order_number: [
          {
            quota_order_number_origins: [
              { geographical_area: :geographical_area_descriptions },
              {
                quota_order_number_origin_exclusions: [
                  { geographical_area: :geographical_area_descriptions },
                ],
              },
            ],
          },
        ],
      },
    ],
  }.freeze

  attr_reader :scope, :current_page, :per_page, :date, :include_quota_balance_events

  delegate :status, to: :query

  def initialize(attributes, current_page, per_page, date, include_quota_balance_events: false)
    @query = QuotaDefinitionsQuery.new(attributes, date)
    @current_page = current_page
    @per_page = per_page
    @date = date
    @include_quota_balance_events = include_quota_balance_events
  end

  def call
    record_count = pagination_record_count

    @scope = query.apply(
      Measure
        .actual
        .eager(eager_load_graph)
        .distinct(:measures__ordernumber)
        .select(Sequel.expr(:measures).*)
        .order(:measures__ordernumber),
    )

    @scope = @scope.paginate(current_page, per_page, record_count)

    @scope.map(&:quota_definition)
  end

  def pagination_record_count
    @pagination_record_count ||= count_total_records
  end

private

  attr_reader :query

  def count_total_records
    query.apply(Measure.actual).count(Sequel.lit('DISTINCT ordernumber'))
  end

  def eager_load_graph
    eager_load = DEFAULT_EAGER_LOAD_GRAPH.deep_dup

    eager_load[:quota_definition] << :latest_quota_balance_event
    eager_load[:quota_definition] << :quota_balance_events if include_quota_balance_events

    eager_load[:quota_definition] << :quota_exhaustion_events if query.eager_quota_exhaustion_events?

    eager_load
  end
end
