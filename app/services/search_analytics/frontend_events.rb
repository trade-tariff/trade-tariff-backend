# frozen_string_literal: true

module SearchAnalytics
  class FrontendEvents
    def self.call(...) = new(...).call

    def initialize(records:, dates:, supported:, offer_records: [])
      @dates = dates.uniq.sort
      @records = supported ? records.select { |record| @dates.include?(record.reporting_date) } : []
      @offer_records = supported ? offer_records.select { |record| @dates.include?(record.reporting_date) } : []
      @supported = supported
      @rows = @records.flat_map { |record| record.rows.to_a }
    end

    def call
      collected = @records.map(&:reporting_date).uniq.sort
      {
        'available' => @supported && collected.any?,
        'coverage' => {
          'supported' => @supported,
          'expected_days' => @dates.size,
          'collected_days' => collected.size,
          'collected_dates' => collected.map(&:iso8601),
          'missing_dates' => (@dates - collected).map(&:iso8601),
          'complete' => @supported && collected == @dates,
        },
        'generated_at' => @records.map(&:collected_at).max&.iso8601,
        'observed_journeys' => @rows.map { |row| row.fetch('journey_key') }.uniq.size,
        'observed_sessions' => @rows.filter_map { |row| row['session_key'] }.uniq.size,
        'outcomes' => FrontendEventsQuery::OUTCOMES.map { |outcome| outcome_counts(outcome) },
        'actions' => FrontendEventsQuery::ACTIONS.index_with { |action| count(@rows.select { |row| row['outcome'] == action }) },
        'selections' => selections,
        'selection_coverage' => selection_coverage,
        'question_counts' => question_counts,
      }
    end

  private

    def count(rows) = rows.sum { |row| row.fetch('event_count').to_i }

    def outcome_counts(outcome)
      rendered = @rows.select { |row| row['outcome'] == outcome }
      visible = @rows.select { |row| row['outcome'] == 'page_visible' && row['destination'] == outcome }
      observations = visible.sum { |row| row.fetch('navigation_observations').to_i }
      total = visible.sum { |row| row.fetch('navigation_total_ms').to_f }
      {
        'outcome' => outcome,
        'rendered_events' => count(rendered),
        'visible_events' => count(visible),
        'journeys' => (rendered + visible).map { |row| row.fetch('journey_key') }.uniq.size,
        'timed_visible_events' => observations,
        'average_navigation_ms' => observations.positive? ? total / observations : nil,
      }
    end

    def selections
      selected = selection_groups(@rows.select { |row| row['outcome'] == 'result_selected' })
      offered = selection_groups(@offer_records.flat_map { |record| record.rows.to_a })
      complete = selection_coverage.fetch('complete')
      (selected.keys | offered.keys).map { |rank, confidence|
        key = [rank, confidence]
        events = count(selected.fetch(key, []))
        offers = complete ? count(offered.fetch(key, [])) : nil
        {
          'result_rank' => rank,
          'confidence' => confidence,
          'event_count' => events,
          'offered_count' => offers,
          'selection_rate' => offers&.positive? ? 100.0 * events / offers : nil,
        }
      }.sort_by { |row| [row['result_rank'], row['confidence'].to_s] }
    end

    def selection_groups(rows)
      rows.select { |row| Integer(row['result_rank'], exception: false) }.group_by do |row|
        [Integer(row['result_rank'], exception: false), sql_presence(row['confidence'])]
      end
    end

    def selection_coverage
      frontend = @records.index_by(&:reporting_date)
      offers = @offer_records.index_by(&:reporting_date)
      collected = @dates.select do |date|
        next false unless frontend[date] && offers[date]
        # Offers without frontend events cannot establish selection telemetry.
        next false if offers[date].rows.any? && frontend[date].rows.empty?

        # An empty scan cannot establish historical offer telemetry when results
        # or clicks were recorded before result_offered logging existed.
        result_activity = frontend[date].rows.any? do |row|
          %w[results result_selected].include?(row['outcome']) || (row['outcome'] == 'page_visible' && row['destination'] == 'results')
        end
        offers[date].rows.any? || !result_activity
      end
      {
        'complete' => @supported && collected == @dates,
        'collected_days' => collected.size,
        'expected_days' => @dates.size,
        'missing_dates' => (@dates - collected).map(&:iso8601),
      }
    end

    def sql_presence(value)
      present = value.presence
      present == 'null' ? nil : present
    end

    def question_counts
      maxima = @rows.group_by { |row| row.fetch('journey_key') }.values.map do |rows|
        rows.filter_map { |row| Integer(row['reported_questions'], exception: false) }.max
      end
      maxima.tally.sort_by { |questions, _count| questions || -1 }.map do |questions, journeys|
        { 'questions' => questions, 'journeys' => journeys }
      end
    end
  end
end
