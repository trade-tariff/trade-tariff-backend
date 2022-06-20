module TradeTariffBackend
  class << self
    SERVICE_CURRENCIES = {
      'uk' => 'GBP',
      'xi' => 'EUR',
    }.freeze

    def configure
      yield self
    end

    # Lock key used for DB locks to keep just one instance of synchronizer
    # running in cluster environment
    def db_lock_key
      'tariff-lock'
    end

    def log_formatter
      proc { |severity, time, _progname, msg| "#{time.strftime('%Y-%m-%dT%H:%M:%S.%L %z')} #{sprintf('%5s', severity)} #{msg}\n" }
    end

    # Email of the user who receives all info/error notifications
    def from_email
      ENV.fetch('TARIFF_FROM_EMAIL')
    end

    # Email of the user who receives all info/error notifications
    def admin_email
      ENV.fetch('TARIFF_SYNC_EMAIL')
    end

    def use_cds?
      ENV['CDS'] == 'true'
    end

    def patch_broken_taric_downloads?
      ENV['PATCH_BROKEN_TARIC_DOWNLOADS'] == 'true'
    end

    def uk?
      service == 'uk'
    end

    def xi?
      service == 'xi'
    end

    def platform
      Rails.env
    end

    def service
      ENV.fetch('SERVICE', 'uk')
    end

    def deployed_environment
      PaasConfig.space
    end

    def currency
      SERVICE_CURRENCIES.fetch(service, 'GBP')
    end

    def data_migration_path
      Rails.root.join('db/data_migrations')
    end

    def with_redis_lock(lock_name = db_lock_key, &block)
      lock = Redlock::Client.new([RedisLockDb.redis])
      lock.lock!(lock_name, 5000, &block)
    end

    def redis
      @redis ||= Redis.new(PaasConfig.redis)
    end

    def reindex(indexer = search_client)
      TimeMachine.with_relevant_validity_periods do
        indexer.update
      rescue StandardError => e
        Mailer.reindex_exception(e).deliver_now
      end
    end

    def recache(indexer = cache_client)
      indexer.update
    rescue StandardError => e
      Mailer.reindex_exception(e).deliver_now
    end

    # Number of changes to fetch for Commodity/Heading/Chapter
    def change_count
      10
    end

    def number_formatter
      @number_formatter ||= TradeTariffBackend::NumberFormatter.new
    end

    def search_client
      @search_client ||= SearchClient.new(
        Elasticsearch::Client.new,
        indexed_models:,
        index_page_size: 500,
        search_operation_options:,
      )
    end

    def cache_client
      @cache_client ||= SearchClient.new(
        Elasticsearch::Client.new,
        namespace: 'cache',
        indexed_models: cached_models,
        index_page_size: 5,
        search_operation_options:,
      )
    end

    def search_namespace
      @search_namespace ||= 'tariff'
    end
    attr_writer :search_namespace, :search_operation_options

    # Returns search index instance for given model instance or
    # model class instance
    def search_index_for(namespace, model)
      index_name = model.is_a?(Class) ? model : model.class

      "::#{namespace.capitalize}::#{index_name}Index".constantize.new(search_namespace)
    end

    def search_operation_options
      @search_operation_options || {}
    end

    def indexed_models
      [
        Chapter,
        Commodity,
        Heading,
        SearchReference,
        Section,
      ]
    end

    def cached_models
      [
        Heading,
        Certificate,
        AdditionalCode,
        Footnote,
      ]
    end

    def clearable_models
      [
        AdditionalCode,
        AdditionalCodeDescription,
        AdditionalCodeDescriptionPeriod,
        BaseRegulation,
        Certificate,
        CertificateDescription,
        CertificateDescriptionPeriod,
        CertificateType,
        Change,
        DutyExpression,
        ExportRefundNomenclature,
        ExportRefundNomenclatureDescription,
        ExportRefundNomenclatureDescriptionPeriod,
        ExportRefundNomenclatureIndent,
        Footnote,
        FootnoteAssociationGoodsNomenclature,
        FootnoteDescription,
        FootnoteDescriptionPeriod,
        FullTemporaryStopRegulation,
        GeographicalArea,
        GeographicalAreaDescription,
        GeographicalAreaDescriptionPeriod,
        GeographicalAreaMembership,
        GoodsNomenclature,
        GoodsNomenclatureDescription,
        GoodsNomenclatureDescriptionPeriod,
        GoodsNomenclatureIndent,
        Measure,
        MeasureAction,
        MeasureComponent,
        MeasureCondition,
        MeasureConditionCode,
        MeasureConditionComponent,
        MeasurePartialTemporaryStop,
        MeasureType,
        MeasurementUnit,
        MeasurementUnitQualifier,
        MeursingAdditionalCode,
        ModificationRegulation,
        MonetaryExchangePeriod,
        MonetaryUnit,
        NationalMeasurementUnitSet,
        PublicationSigle,
        QuotaBlockingPeriod,
        QuotaDefinition,
        QuotaOrderNumber,
        QuotaOrderNumberOrigin,
        QuotaSuspensionPeriod,
      ]
    end

    def search_indexes
      indexed_models.map do |model|
        "::Search::#{model}Index".constantize.new(search_namespace)
      end
    end

    def model_serializer_for(namespace, model)
      "::#{namespace.capitalize}::#{model}Serializer".constantize
    end

    def api_version(request)
      request.headers['Accept']&.scan(/application\/vnd.uktt.v(\d+)/)&.flatten&.first || '1'
    end

    def error_serializer(request)
      "Api::V#{api_version(request)}::ErrorSerializationService".constantize.new
    end

    def rules_of_origin
      @rules_of_origin ||= RulesOfOrigin::DataSet.load_default
    end

    def chief_cds_guidance
      @chief_cds_guidance ||= ChiefCdsGuidance.load_default
    end

    def normalised_measure_units?
      ENV['NORMALISED_MEASURE_UNITS'].to_s == 'true'
    end

    def handle_cascade_soft_deletes?
      ENV['SOFT_DELETES_CASCADE'].to_s == 'true'
    end

    def handle_missing_soft_deletes?
      ENV['SOFT_DELETES_MISSING'].to_s == 'true'
    end
  end
end
