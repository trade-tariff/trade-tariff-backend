# frozen_string_literal: true

module SearchAnalytics
  # Reads pre-aggregated outcome counts. It does not scan identities in Ruby
  # and it does not refresh views or collect logs.
  class OutcomeRates
    GUIDED_OUTCOMES = %w[results no_results unknown_results blocking_guidance error dont_know abandonment].freeze
    CLASSIC_OUTCOMES = %w[results no_results].freeze
    QUESTION_OUTCOMES = %w[server_accepted dont_know unanswered].freeze
    PERCENTAGE_POINTS = 10_000
    LIMITATIONS = [
      'Classic rates count completed frontend-origin fuzzy searches from backend logs. They do not prove that a results page was visible. Exact matches are excluded. Empty means total result_count 0, not a commodity-only or heading-only count.',
      'Guided rates use same-day initial_submitted request IDs. The class is the latest page_visible terminal destination or dont_know that UTC day. A server-rendered outcome is not visibility. There is no inactivity timeout and no cross-day join.',
      'Missing or failed collection is a coverage gap, not abandonment. Static error pages and redirects to /500, /404, /429, or an invalid date are not observed, so they are not counted as seen errors.',
      'No-JS "I don\'t know" is not a dont_know event. A no-JS answer that matches a rendered option counts as server_accepted. Browser answer_submitted events are not counted.',
      'A changed frontend_events or classic_outcomes definition does not reclassify stored history. Those days stay stale until recollection.',
    ].freeze

    def self.call(...) = new(...).call

    def initialize(service:, dates:, view:, definitions:)
      @service = service
      @dates = dates.uniq.sort
      @view = view
      @definitions = definitions
    end

    def call
      {
        'outcome_rates' => {
          'classic' => population(:classic),
          'guided' => population(:guided),
          'limitations' => LIMITATIONS,
        },
        'question_outcomes' => population(:questions),
      }
    end

  private

    def population(kind)
      supported = supported?(kind)
      base = {
        'supported' => supported,
        'available' => false,
        'denominator' => nil,
        'counts' => nil,
        'percentages' => nil,
        'percentage_status' => supported ? 'unavailable' : 'unsupported',
        'coverage' => coverage_shell(supported),
        'limitations' => LIMITATIONS,
      }
      return base unless supported
      return base.merge('reason' => 'not_bootstrapped') unless OutcomeRatesViews.ready?

      fresh = fresh_dates(source_name(kind))
      unless fresh.fetch(:dates).any?
        return base.merge('reason' => 'no_fresh_days', 'coverage' => fresh.fetch(:coverage))
      end

      counts = counts_for(kind, fresh.fetch(:dates))
      total = counts.values.sum
      base.merge(
        'available' => true,
        'reason' => nil,
        'denominator' => total,
        'counts' => counts,
        'percentages' => percentages(counts),
        'percentage_status' => total.positive? ? 'available' : 'unavailable',
        'coverage' => fresh.fetch(:coverage),
      )
    end

    def supported?(kind)
      case kind
      when :classic then @view != 'internal'
      when :guided, :questions then @service == 'uk' && @view != 'classic'
      else false
      end
    end

    def source_name(kind) = kind == :classic ? 'classic_outcomes' : 'frontend_events'

    def coverage_shell(supported)
      {
        'supported' => supported,
        'expected_days' => @dates.size,
        'collected_days' => 0,
        'fresh_days' => 0,
        'collected_dates' => [],
        'fresh_dates' => [],
        'missing_dates' => supported ? @dates.map(&:iso8601) : [],
        'stale_dates' => [],
        'unprojected_dates' => [],
        'complete' => false,
      }
    end

    def fresh_dates(name)
      live = SearchAnalyticsQueryResult
        .where(service: @service, reporting_date: @dates, name:)
        .select(:id, :service, :reporting_date, :name, :fingerprint, :collected_at)
        .all
      collected = live.map { |row| row.reporting_date.to_date }.uniq.sort
      current = live.select { |row| row.fingerprint == @definitions.fetch(name) }
      snapshot = OutcomeSourceRevision.where(service: @service, name:, reporting_date: current.map(&:reporting_date)).all
      fresh = current.select { |row| projected?(row, snapshot) }.map { |row| row.reporting_date.to_date }.uniq.sort
      stale = collected - current.map { |row| row.reporting_date.to_date }.uniq
      unprojected = current.map { |row| row.reporting_date.to_date }.uniq - fresh
      {
        dates: fresh,
        coverage: {
          'supported' => true,
          'expected_days' => @dates.size,
          'collected_days' => collected.size,
          'fresh_days' => fresh.size,
          'collected_dates' => collected.map(&:iso8601),
          'fresh_dates' => fresh.map(&:iso8601),
          'missing_dates' => (@dates - collected).map(&:iso8601),
          'stale_dates' => stale.map(&:iso8601),
          'unprojected_dates' => unprojected.map(&:iso8601),
          'complete' => @dates.any? && fresh == @dates,
        },
      }
    end

    def projected?(row, snapshot)
      match = snapshot.find { |item| item.reporting_date.to_date == row.reporting_date.to_date }
      return false unless match
      return false unless match.definition_version == OutcomeRatesViews::VERSION

      match.id == row.id &&
        match.fingerprint == row.fingerprint &&
        match.collected_at.utc.iso8601(6) == row.collected_at.utc.iso8601(6)
    end

    def counts_for(kind, dates)
      keys = count_keys(kind)
      return keys.index_with { 0 } if dates.empty?

      column = { classic: :searches, questions: :questions }.fetch(kind, :journeys)
      stored = count_model(kind).where(service: @service, reporting_date: dates).all
      totals = stored.group_by(&:outcome).transform_values { |rows| rows.sum { |row| row[column].to_i } }
      keys.index_with { |key| totals.fetch(key, 0) }
    end

    def count_keys(kind)
      case kind
      when :classic then CLASSIC_OUTCOMES
      when :questions then QUESTION_OUTCOMES
      else GUIDED_OUTCOMES
      end
    end

    def count_model(kind)
      case kind
      when :classic then ClassicOutcomeCount
      when :questions then QuestionOutcomeCount
      else GuidedOutcomeCount
      end
    end

    def percentages(counts)
      total = counts.values.sum
      return if total.zero?

      floors = counts.transform_values { |count| count * PERCENTAGE_POINTS / total }
      remainder = PERCENTAGE_POINTS - floors.values.sum
      order = counts.sort_by { |key, count| [-(count * PERCENTAGE_POINTS % total), key] }.map(&:first)
      order.first(remainder).each { |key| floors[key] += 1 }
      floors.transform_values { |points| points / 100.0 }
    end
  end
end
