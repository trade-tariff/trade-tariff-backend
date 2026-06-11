# frozen_string_literal: true

module SearchAnalytics
  class Period < Data.define(:key, :view, :duration, :bucket_size)
    PERIODS = { '24h' => [24.hours, 'hour'], '7d' => [7.days, 'day'], '30d' => [30.days, 'day'] }.freeze

    VIEWS = %w[all classic internal].freeze
    DEFAULT_PERIOD = '24h'
    DEFAULT_VIEW = 'all'

    def self.for(period:, view:)
      period_key = PERIODS.key?(period) ? period : DEFAULT_PERIOD
      view_key = VIEWS.include?(view) ? view : DEFAULT_VIEW
      duration, bucket_size = PERIODS.fetch(period_key)

      new(key: period_key, view: view_key, duration:, bucket_size:)
    end
  end
end
