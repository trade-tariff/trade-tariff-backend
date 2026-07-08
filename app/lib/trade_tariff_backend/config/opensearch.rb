module TradeTariffBackend
  module Config
    module Opensearch
      def opensearch_host
        ENV.fetch('ELASTICSEARCH_URL', 'http://host.docker.internal:9200')
      end

      def opensearch_debug
        ENV.fetch('OPENSEARCH_DEBUG', 'false') == 'true'
      end

      def opensearch_configuration
        { host: opensearch_host, log: opensearch_debug }
      end
    end
  end
end
