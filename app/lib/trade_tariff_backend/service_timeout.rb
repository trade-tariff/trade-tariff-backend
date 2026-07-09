# frozen_string_literal: true

module TradeTariffBackend
  class ServiceTimeout
    DEFAULT_TIMEOUT = 50
    DEFAULT_PATH_OVERRIDES = '/uk/internal/search:100,/xi/internal/search:100'

    class << self
      def timeout_for(path)
        path_timeouts.each do |prefix, seconds|
          return seconds if path_match?(path, prefix)
        end

        default_timeout
      end

      def default_timeout
        ENV.fetch('RACK_TIMEOUT_SERVICE_TIMEOUT', DEFAULT_TIMEOUT).to_i
      end

      def path_timeouts
        parse_path_timeouts
      end

    private

      def parse_path_timeouts
        ENV.fetch('RACK_TIMEOUT_PATH_OVERRIDES', DEFAULT_PATH_OVERRIDES)
           .split(',')
           .filter_map do |entry|
             parts = entry.strip.split(':')
             next if parts.length < 2

             [parts[0], parts[1].to_i]
           end
      end

      def path_match?(path, prefix)
        path == prefix || path.start_with?("#{prefix}/")
      end
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      timeout = self.class.timeout_for(env['PATH_INFO'])
      ::Timeout.timeout(timeout) { @app.call(env) }
    end
  end
end
