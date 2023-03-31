module HeadingService
  class HeadingSerializationService
    delegate :nested_set_headings?, to: TradeTariffBackend

    def initialize(heading, actual_date, filters = {})
      @heading = heading
      @actual_date = actual_date
      @filters = filters
    end

    def serializable_hash
      Rails.cache.fetch("_#{heading_cache_key}", expires_in: 24.hours) do
        serialization_service.serializable_hash
      end
    end

    private

    attr_reader :heading, :actual_date, :filters

    def serialization_service
      if heading.declarable?
        HeadingService::Serialization::DeclarableService
          .new(heading, filters)
      elsif nested_set_headings?
        HeadingService::Serialization::NsNondeclarableService
          .new(heading)
      else
        HeadingService::Serialization::NondeclarableService
          .new(heading, actual_date)
      end
    end

    def heading_cache_key
      "heading-#{TradeTariffBackend.service}-#{heading.goods_nomenclature_sid}-#{actual_date}-#{heading.declarable?}-#{filters_hash}"
    end

    def filters_hash
      Digest::MD5.hexdigest(filters.to_json)
    end
  end
end
