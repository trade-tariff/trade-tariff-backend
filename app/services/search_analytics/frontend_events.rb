# frozen_string_literal: true

module SearchAnalytics
  class FrontendEvents
    def self.call(...) = new(...).call

    def initialize(records:, dates:, supported:)
      @dates = dates.uniq.sort
      @records = supported ? records.select { |record| @dates.include?(record.reporting_date) } : []
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
      @rows.select { |row| row['outcome'] == 'result_selected' && Integer(row['result_rank'], exception: false) }.group_by { |row|
        [Integer(row['result_rank'], exception: false), sql_presence(row['confidence'])]
      }.map { |(rank, confidence), rows|
        { 'result_rank' => rank, 'confidence' => confidence, 'event_count' => count(rows) }
      }.sort_by { |row| [row['result_rank'], row['confidence'].to_s] }
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
