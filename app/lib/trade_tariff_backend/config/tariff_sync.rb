module TradeTariffBackend
  module Config
    module TariffSync
      def tariff_sync_username
        ENV['TARIFF_SYNC_USERNAME']
      end

      def tariff_sync_password
        ENV['TARIFF_SYNC_PASSWORD']
      end

      def tariff_sync_host
        ENV['TARIFF_SYNC_HOST']
      end

      def tariff_ignore_presence_errors
        ENV.fetch('TARIFF_IGNORE_PRESENCE_ERRORS', '1') == '1'
      end

      def patch_broken_taric_downloads?
        ENV['PATCH_BROKEN_TARIC_DOWNLOADS'] == 'true'
      end

      def dump_cds_data_as_json?
        ENV.fetch('DUMP_CDS_DATA_AS_JSON', 'false') == 'true'
      end

      def cds_importer_batch_size
        fetch_positive_int('CDS_IMPORT_BATCH_SIZE', 100)
      end

      def taric_importer_batch_size
        fetch_positive_int('TARIC_IMPORT_BATCH_SIZE', 100)
      end

      def taric_importer_batch_size
        ENV.fetch('TARIC_IMPORT_BATCH_SIZE', '100').to_i
      end

      def implicit_deletion_cutoff
        Date.parse(ENV.fetch('IMPLICIT_DELETION_CUTOFF', '2024-03-25'))
      end

      def fetch_positive_int(key, default_val)
        value = ENV.fetch(key, default_val).to_i
        value.positive? ? value : default_val
      end
    end
  end
end
