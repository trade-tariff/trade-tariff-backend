module TradeTariffBackend
  module Config
    module Infrastructure
      def max_threads
        ENV.fetch('MAX_THREADS', '6').to_i
      end

      def aws_region
        ENV.fetch('AWS_REGION', 'eu-west-2')
      end

      def allow_missing_migration_files
        ENV.fetch('ALLOW_MISSING_MIGRATION_FILES', 'true') == 'true'
      end

      def excess_query_threshold
        @excess_query_threshold ||= ENV['EXCESS_QUERY_THRESHOLD'].to_i
      end

      def check_query_count?
        excess_query_threshold.positive?
      end
    end
  end
end
