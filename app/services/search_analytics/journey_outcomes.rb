# frozen_string_literal: true

module SearchAnalytics
  class JourneyOutcomes
    State = Data.define(:kind, :window_end)
    FLAGS = { 'selected' => 1, 'zero_result' => 2, 'questions_seen' => 4, 'unknown_seen' => 8 }.freeze
    SERIES = %w[completed failed nonterminal unknown zero_result selected].freeze

    def self.call(...) = new(...).call

    def initialize(journeys:, records:, dates:, buckets:)
      @journeys = journeys
      @records = records
      @dates = dates
      @buckets = buckets
      @index = journeys.keys
      @index.each_key.with_index { |key, index| @index[key] = index }
      @states = Array.new(@index.size)
      @flags = Array.new(@index.size, 0)
      @questions = Array.new(@index.size)
    end

    def call
      collected = @dates.select do |date|
        rows = @records.where(reporting_date: date).get(:rows)
        next false unless rows

        rows.each { |row| consume(row) }
        true
      end
      complete = collected == @dates
      {
        'coverage' => {
          'complete' => complete,
          'expected_days' => @dates.size,
          'collected_days' => collected.size,
          'missing_dates' => (@dates - collected).map(&:iso8601),
        },
        'summary' => complete ? counts(@index.keys) : nil,
        'question_counts' => complete ? question_counts : [],
        'trend' => complete ? trend : [],
      }
    end

  private

    def consume(row)
      state = State.new(kind: row.fetch('terminal_state'), window_end: Time.iso8601(row.fetch('window_end')))
      flags = FLAGS.sum { |name, bit| row.fetch(name).to_i.positive? ? bit : 0 }
      questions = Integer(row['total_questions'], exception: false)
      row.fetch('journey_keys').each do |key|
        index = @index[key]
        next if index.nil?

        @flags[index] |= flags
        if questions
          previous_questions = @questions[index]
          @questions[index] = previous_questions.nil? ? questions : [previous_questions, questions].max
        end
        next if state.kind == 'none'

        previous = @states[index]
        if previous.nil? || state.window_end > previous.window_end
          @states[index] = state
        elsif state.window_end == previous.window_end && state.kind != previous.kind
          @states[index] = state.with(kind: 'conflict')
        end
      end
    end

    def status(index)
      state = @states[index]
      return state.kind if state && %w[completed failed].include?(state.kind)
      return 'unknown' if state || (@flags[index] & FLAGS.fetch('unknown_seen')).positive?

      (@flags[index] & FLAGS.fetch('questions_seen')).positive? ? 'nonterminal' : 'unknown'
    end

    def counts(keys)
      keys.each_with_object(SERIES.index_with { 0 }) do |key, totals|
        index = @index.fetch(key)
        totals[status(index)] += 1
        %w[selected zero_result].each { |name| totals[name] += 1 if (@flags[index] & FLAGS.fetch(name)).positive? }
      end
    end

    def question_counts
      @index.keys.map { |key| @questions[@index.fetch(key)] }.tally.sort_by { |questions, _count| questions || -1 }.map do |questions, journeys|
        { 'questions' => questions, 'journeys' => journeys }
      end
    end

    def trend
      memberships = @journeys.keys_by_bucket
      @buckets.map { |bucket| { 'bucket' => bucket }.merge(counts(memberships.fetch(bucket, {}).keys)) }
    end
  end
end
