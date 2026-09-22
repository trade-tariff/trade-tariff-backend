# frozen_string_literal: true

module Search
  # Emits low-cardinality search metrics as a raw CloudWatch Embedded Metric
  # Format line. Rails.logger prefixes lines, so this writes to stdout directly.
  # CloudWatch extracts the metrics from that line. A dropped write must not
  # affect the search that produced the event.
  class Metrics
    NAMESPACE = 'TradeTariff/Search'
    MAX_LINE_BYTES = 4096
    REQUEST_SOURCES = %w[frontend admin mcp backend_only].freeze
    SEARCH_TYPES = %w[classic interactive internal evaluation classification].freeze
    METRIC_NAMES = %w[
      SearchEvents
      SearchDuration
      ResultSelections
      QueryExpansions
      AiApiDuration
      EmptyResults
      ResultCount
      CommodityResultCount
    ].freeze

    class << self
      def subscribe!(output: $stdout)
        unsubscribe!
        # config.x outlives a Zeitwerk reload. A class ivar does not, so to_prepare would subscribe twice.
        subscription_registry.search_metrics_subscriber = ActiveSupport::Notifications.subscribe(/\.search\z/) do |*args|
          record(ActiveSupport::Notifications::Event.new(*args), output:)
        end
      end

      def unsubscribe!
        subscriber = subscription_registry.search_metrics_subscriber
        return unless subscriber

        ActiveSupport::Notifications.unsubscribe(subscriber)
        subscription_registry.search_metrics_subscriber = nil
      end

      def record(event, output: $stdout, environment: TradeTariffBackend.environment, service: TradeTariffBackend.service, now: Time.current)
        payload = payload_for(event, environment:, service:, now:)
        return false unless payload

        line = "#{JSON.generate(payload)}\n"
        return false if line.bytesize > MAX_LINE_BYTES

        output.write_nonblock(line, exception: false) == line.bytesize
      rescue StandardError
        false
      end

    private

      def payload_for(event, environment:, service:, now:)
        name = event.name.to_s.delete_suffix('.search')
        dimensions = base_dimensions(environment, service)
        metrics = []
        values = {}

        case name
        when 'search_completed'
          add_search_event(event.payload, dimensions, metrics, values, outcome: 'completed')
          add_duration(metrics, values, 'SearchDuration', event.payload[:total_duration_ms])
          add_result_metrics(event.payload, metrics, values)
        when 'search_failed'
          add_search_event(event.payload, dimensions, metrics, values, outcome: 'failed')
        when 'result_selected'
          metrics << metric('ResultSelections', [%w[Environment Service]])
          values[:ResultSelections] = 1
        when 'query_expanded'
          metrics << metric('QueryExpansions', [%w[Environment Service]])
          values[:QueryExpansions] = 1
        when 'api_call_completed'
          add_duration(metrics, values, 'AiApiDuration', event.payload[:duration_ms])
        else
          return
        end
        return if metrics.empty?

        dimensions.merge(values).merge(emf(metrics, now))
      end

      def add_search_event(payload, dimensions, metrics, values, outcome:)
        dimensions[:RequestSource] = label(payload[:request_source], REQUEST_SOURCES)
        dimensions[:SearchType] = label(payload[:search_type], SEARCH_TYPES)
        dimensions[:Outcome] = outcome
        values[:SearchEvents] = 1
        metrics << metric('SearchEvents', [
          %w[Environment Service RequestSource Outcome],
          %w[Environment Service SearchType Outcome],
          %w[Environment Service Outcome],
        ])
      end

      def add_result_metrics(payload, metrics, values)
        result_count = number(payload[:result_count])
        commodity_count = number(payload[:commodity_result_count])
        if result_count
          values[:ResultCount] = result_count
          metrics << metric('ResultCount', [%w[Environment Service SearchType]])
        end
        if commodity_count
          values[:CommodityResultCount] = commodity_count
          metrics << metric('CommodityResultCount', [%w[Environment Service SearchType]])
        end
        return unless empty_result?(payload)

        values[:EmptyResults] = 1
        metrics << metric('EmptyResults', [%w[Environment Service SearchType]])
      end

      def add_duration(metrics, values, name, milliseconds)
        seconds = seconds(milliseconds)
        return unless seconds

        values[name.to_sym] = seconds
        metrics << metric(name, [%w[Environment Service]])
      end

      # Keep aligned with search_quality_dashboard zero_result_condition.
      # Classic exact matches are not empty commodity results. Missing counts
      # are not treated as zero except the classic fallback below.
      def empty_result?(payload)
        search_type = payload[:search_type].to_s
        result_count = payload[:result_count]
        commodity_count = payload[:commodity_result_count]

        if search_type == 'classic'
          if commodity_count.nil?
            !result_count.nil? && result_count.to_f.zero?
          else
            commodity_count.to_f.zero? && payload[:results_type].to_s != 'exact_search'
          end
        elsif %w[interactive internal].include?(search_type)
          !result_count.nil? && result_count.to_f.zero?
        else
          false
        end
      end

      def base_dimensions(environment, service)
        {
          Environment: environment.to_s,
          Service: service.to_s,
        }
      end

      def label(value, allowed)
        text = value.to_s
        return 'unknown' if text.empty?
        return text if allowed.include?(text)

        'other'
      end

      def number(value)
        return unless value.is_a?(Numeric) && value.finite? && value >= 0

        value
      end

      def seconds(milliseconds)
        value = number(milliseconds)
        return unless value

        value / 1000.0
      end

      def metric(name, dimensions)
        {
          Namespace: NAMESPACE,
          Dimensions: dimensions,
          Metrics: [{ Name: name, Unit: name.end_with?('Duration') ? 'Seconds' : 'Count' }],
        }
      end

      def emf(metrics, now)
        {
          _aws: {
            Timestamp: (now.to_f * 1000).to_i,
            CloudWatchMetrics: metrics,
          },
        }
      end

      def subscription_registry
        Rails.application.config.x
      end
    end
  end
end
