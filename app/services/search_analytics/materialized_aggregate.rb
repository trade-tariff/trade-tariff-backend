# frozen_string_literal: true

module SearchAnalytics
  class MaterializedAggregate < DailyAggregate
    Metrics = Data.define(:projection, :view) do
      def count = projection.summary(view).fetch('journeys')
      delegate :trend, to: :projection
    end

    def initialize(period:, results:, projection:, query_dates: nil)
      @projection = projection
      super(
        period:,
        results: results.merge('search_term_improvements' => [], 'item_id_improvements' => []),
        journeys: Period::VIEWS.index_with { |view| Metrics.new(projection:, view:) },
        cost_keys: projection.cost_keys,
        query_dates:,
      )
    end

  private

    def improvement_terms(_view) = @projection.terms

    def iso8601(value)
      @iso8601 ||= {}
      return @iso8601[value] if @iso8601.key?(value)

      @iso8601[value] = super
    end
  end
end
