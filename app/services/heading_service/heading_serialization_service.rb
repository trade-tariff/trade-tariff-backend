module HeadingService
  class HeadingSerializationService
    CACHE_VERSION = 'v1'.freeze

    class << self
      def cache_key(heading, actual_date, is_declarable, filters)
        cache_key = [
          'heading',
          TradeTariffBackend.service,
          heading.goods_nomenclature_sid,
          date_string(actual_date),
          is_declarable,
          filters_hash(filters),
          CACHE_VERSION,
        ]

        "_#{cache_key.map(&:to_s).join('-')}"
      end

    private

      def filters_hash(filters)
        Digest::MD5.hexdigest(filters.to_json)
      end

      def date_string(date)
        date.is_a?(String) ? date : date.to_date.to_formatted_s(:db)
      end
    end

    def initialize(heading, actual_date, filters = {})
      @heading = heading
      @actual_date = actual_date
      @filters = filters
    end

    def serializable_hash
      Rails.cache.fetch(heading_cache_key, expires_in: 24.hours) do
        serialization_service.serializable_hash
      end
    end

    private

    attr_reader :heading, :actual_date, :filters

    def serialization_service
      if heading.ns_declarable?
        HeadingService::Serialization::DeclarableService
          .new(heading, filters)
      else
        HeadingService::Serialization::NsNondeclarableService
          .new(heading)
      end
    end

    def heading_cache_key
      self.class.cache_key(heading, actual_date, heading.declarable?, filters)
    end
  end
end
