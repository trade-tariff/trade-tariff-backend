# frozen_string_literal: true

require 'sidekiq/capsule'

module TradeTariffBackend
  # Splits one Sidekiq process into reserved capsules so slow batch jobs
  # cannot occupy every thread before CDS/TARIC sync starts.
  #
  # SIDEKIQ_CONCURRENCY is the total thread budget across capsules.
  # The default capsule keeps the remainder after sync and within_1_day.
  class SidekiqCapsuleConfig
    Capsule = Data.define(:name, :concurrency, :queues)

    DEFAULT_TOTAL_CONCURRENCY = 10
    DEFAULT_SYNC_CONCURRENCY = 3
    DEFAULT_WITHIN_1_DAY_CONCURRENCY = 3

    DEFAULT_QUEUES = %w[default within_1_hour].freeze
    SYNC_QUEUES = %w[sync].freeze
    WITHIN_1_DAY_QUEUES = %w[within_1_day].freeze

    def initialize(env = ENV)
      @env = env
    end

    def capsules
      [
        Capsule.new(name: 'default', concurrency: default_concurrency, queues: DEFAULT_QUEUES),
        Capsule.new(name: 'sync', concurrency: sync_concurrency, queues: SYNC_QUEUES),
        Capsule.new(name: 'within_1_day', concurrency: within_1_day_concurrency, queues: WITHIN_1_DAY_QUEUES),
      ]
    end

    def apply!(config)
      capsules.each do |capsule|
        config.capsule(capsule.name) do |cap|
          cap.concurrency = capsule.concurrency
          cap.queues = capsule.queues
        end
      end

      config
    end

    def total_concurrency
      int('SIDEKIQ_CONCURRENCY', DEFAULT_TOTAL_CONCURRENCY)
    end

    def sync_concurrency
      positive_int('SIDEKIQ_SYNC_CONCURRENCY', DEFAULT_SYNC_CONCURRENCY)
    end

    def within_1_day_concurrency
      positive_int('SIDEKIQ_WITHIN_1_DAY_CONCURRENCY', DEFAULT_WITHIN_1_DAY_CONCURRENCY)
    end

    def default_concurrency
      remainder = total_concurrency - sync_concurrency - within_1_day_concurrency
      if remainder < 1
        raise ArgumentError,
              "SIDEKIQ_CONCURRENCY (#{total_concurrency}) must leave at least 1 thread for default after " \
              "SIDEKIQ_SYNC_CONCURRENCY (#{sync_concurrency}) and SIDEKIQ_WITHIN_1_DAY_CONCURRENCY " \
              "(#{within_1_day_concurrency})"
      end

      remainder
    end

  private

    def int(name, default)
      Integer(@env.fetch(name, default))
    end

    def positive_int(name, default)
      value = int(name, default)
      raise ArgumentError, "#{name} must be at least 1 (got #{value})" if value < 1

      value
    end
  end
end
