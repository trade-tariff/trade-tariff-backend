class CdsImporter
  class EntityMapper
    ALL_MAPPERS = [
      CdsImporter::EntityMapper::AdditionalCodeDescriptionMapper,
      CdsImporter::EntityMapper::AdditionalCodeDescriptionPeriodMapper,
      CdsImporter::EntityMapper::AdditionalCodeMapper,
      CdsImporter::EntityMapper::AdditionalCodeTypeDescriptionMapper,
      CdsImporter::EntityMapper::AdditionalCodeTypeMapper,
      CdsImporter::EntityMapper::AdditionalCodeTypeMeasureTypeMapper,
      CdsImporter::EntityMapper::BaseRegulationMapper,
      CdsImporter::EntityMapper::CertificateDescriptionMapper,
      CdsImporter::EntityMapper::CertificateDescriptionPeriodMapper,
      CdsImporter::EntityMapper::CertificateMapper,
      CdsImporter::EntityMapper::CertificateTypeDescriptionMapper,
      CdsImporter::EntityMapper::CertificateTypeMapper,
      CdsImporter::EntityMapper::CompleteAbrogationRegulationMapper,
      CdsImporter::EntityMapper::DutyExpressionDescriptionMapper,
      CdsImporter::EntityMapper::DutyExpressionMapper,
      CdsImporter::EntityMapper::ExplicitAbrogationRegulationMapper,
      CdsImporter::EntityMapper::ExportRefundNomenclatureDescriptionMapper,
      CdsImporter::EntityMapper::ExportRefundNomenclatureDescriptionPeriodMapper,
      CdsImporter::EntityMapper::ExportRefundNomenclatureIndentMapper,
      CdsImporter::EntityMapper::ExportRefundNomenclatureMapper,
      CdsImporter::EntityMapper::FootnoteAssociationAdditionalCodeMapper,
      CdsImporter::EntityMapper::FootnoteAssociationErnMapper,
      CdsImporter::EntityMapper::FootnoteAssociationGoodsNomenclatureMapper,
      CdsImporter::EntityMapper::FootnoteAssociationMeasureMapper,
      CdsImporter::EntityMapper::FootnoteAssociationMeursingHeadingMapper,
      CdsImporter::EntityMapper::FootnoteDescriptionMapper,
      CdsImporter::EntityMapper::FootnoteDescriptionPeriodMapper,
      CdsImporter::EntityMapper::FootnoteMapper,
      CdsImporter::EntityMapper::FootnoteTypeDescriptionMapper,
      CdsImporter::EntityMapper::FootnoteTypeMapper,
      CdsImporter::EntityMapper::FtsRegulationActionMapper,
      CdsImporter::EntityMapper::FullTemporaryStopRegulationMapper,
      CdsImporter::EntityMapper::GeographicalAreaDescriptionMapper,
      CdsImporter::EntityMapper::GeographicalAreaDescriptionPeriodMapper,
      CdsImporter::EntityMapper::GeographicalAreaMapper,
      CdsImporter::EntityMapper::GeographicalAreaMembershipMapper,
      CdsImporter::EntityMapper::GoodsNomenclatureDescriptionMapper,
      CdsImporter::EntityMapper::GoodsNomenclatureDescriptionPeriodMapper,
      CdsImporter::EntityMapper::GoodsNomenclatureGroupDescriptionMapper,
      CdsImporter::EntityMapper::GoodsNomenclatureGroupMapper,
      CdsImporter::EntityMapper::GoodsNomenclatureIndentMapper,
      CdsImporter::EntityMapper::GoodsNomenclatureMapper,
      CdsImporter::EntityMapper::GoodsNomenclatureOriginMapper,
      CdsImporter::EntityMapper::GoodsNomenclatureSuccessorMapper,
      CdsImporter::EntityMapper::LanguageDescriptionMapper,
      CdsImporter::EntityMapper::LanguageMapper,
      CdsImporter::EntityMapper::MeasureActionDescriptionMapper,
      CdsImporter::EntityMapper::MeasureActionMapper,
      CdsImporter::EntityMapper::MeasureComponentMapper,
      CdsImporter::EntityMapper::MeasureConditionCodeDescriptionMapper,
      CdsImporter::EntityMapper::MeasureConditionCodeMapper,
      CdsImporter::EntityMapper::MeasureConditionComponentMapper,
      CdsImporter::EntityMapper::MeasureConditionMapper,
      CdsImporter::EntityMapper::MeasureExcludedGeographicalAreaMapper,
      CdsImporter::EntityMapper::MeasureMapper,
      CdsImporter::EntityMapper::MeasurePartialTemporaryStopMapper,
      CdsImporter::EntityMapper::MeasureTypeDescriptionMapper,
      CdsImporter::EntityMapper::MeasureTypeMapper,
      CdsImporter::EntityMapper::MeasureTypeSeriesDescriptionMapper,
      CdsImporter::EntityMapper::MeasureTypeSeriesMapper,
      CdsImporter::EntityMapper::MeasurementMapper,
      CdsImporter::EntityMapper::MeasurementUnitDescriptionMapper,
      CdsImporter::EntityMapper::MeasurementUnitMapper,
      CdsImporter::EntityMapper::MeasurementUnitQualifierDescriptionMapper,
      CdsImporter::EntityMapper::MeasurementUnitQualifierMapper,
      CdsImporter::EntityMapper::MeursingAdditionalCodeMapper,
      CdsImporter::EntityMapper::MeursingHeadingMapper,
      CdsImporter::EntityMapper::MeursingHeadingTextMapper,
      CdsImporter::EntityMapper::MeursingSubheadingMapper,
      CdsImporter::EntityMapper::MeursingTableCellComponentMapper,
      CdsImporter::EntityMapper::MeursingTablePlanMapper,
      CdsImporter::EntityMapper::ModificationRegulationMapper,
      CdsImporter::EntityMapper::MonetaryExchangePeriodMapper,
      CdsImporter::EntityMapper::MonetaryExchangeRateMapper,
      CdsImporter::EntityMapper::MonetaryUnitDescriptionMapper,
      CdsImporter::EntityMapper::MonetaryUnitMapper,
      CdsImporter::EntityMapper::NomenclatureGroupMembershipMapper,
      CdsImporter::EntityMapper::ProrogationRegulationActionMapper,
      CdsImporter::EntityMapper::ProrogationRegulationMapper,
      CdsImporter::EntityMapper::QuotaAssociationMapper,
      CdsImporter::EntityMapper::QuotaBalanceEventMapper,
      CdsImporter::EntityMapper::QuotaBlockingPeriodMapper,
      CdsImporter::EntityMapper::QuotaCriticalEventMapper,
      CdsImporter::EntityMapper::QuotaDefinitionMapper,
      CdsImporter::EntityMapper::QuotaExhaustionEventMapper,
      CdsImporter::EntityMapper::QuotaOrderNumberMapper,
      CdsImporter::EntityMapper::QuotaOrderNumberOriginExclusionMapper,
      CdsImporter::EntityMapper::QuotaOrderNumberOriginMapper,
      CdsImporter::EntityMapper::QuotaReopeningEventMapper,
      CdsImporter::EntityMapper::QuotaSuspensionPeriodMapper,
      CdsImporter::EntityMapper::QuotaUnblockingEventMapper,
      CdsImporter::EntityMapper::QuotaUnsuspensionEventMapper,
      CdsImporter::EntityMapper::RegulationGroupDescriptionMapper,
      CdsImporter::EntityMapper::RegulationGroupMapper,
      CdsImporter::EntityMapper::RegulationReplacementMapper,
      CdsImporter::EntityMapper::RegulationRoleTypeDescriptionMapper,
      CdsImporter::EntityMapper::RegulationRoleTypeMapper,
    ].freeze

    delegate :instrument, to: ActiveSupport::Notifications

    attr_reader :xml_node, :key

    def initialize(key, xml_node)
      @key = key
      @xml_node = xml_node
      @filename = xml_node.delete('filename')
    end

    def import
      # select all mappers that have mapping_root equal to current xml key
      # it means that every selected mapper requires fetched by this xml key
      # sort mappers to apply top level first
      # e.g. Footnote before FootnoteDescription
      mappers = ALL_MAPPERS.select  { |m| m.mapping_root == key }
                           .sort_by { |m| m.mapping_path ? m.mapping_path.length : 0 }

      mappers.each.with_object({}) do |mapper, oplog_inserts_performed|
        mapper.before_building_model_callbacks.each { |callback| callback.call(xml_node) }

        instances = mapper.new(xml_node).parse

        mapper.before_oplog_inserts_callbacks.each { |callback| callback.call(xml_node) }

        instances.each do |i|
          oplog_inserts_performed[i.operation_klass.to_s] ||= 0

          oplog_oid = logger_enabled? ? save_record(i) : save_record!(i)

          oplog_inserts_performed[i.operation_klass.to_s] += 1 if oplog_oid
        end
      end
    end

    private

    def save_record!(record)
      values = record.values.except(:oid)

      values.merge!(filename: @filename)

      operation_klass = record.class.operation_klass

      if operation_klass.columns.include?(:created_at)
        values.merge!(created_at: operation_klass.dataset.current_datetime)
      end

      operation_klass.insert(values)
    end

    def save_record(record)
      save_record!(record)
    rescue StandardError => e
      instrument('cds_error.cds_importer', record: record, xml_key: key, xml_node: xml_node, exception: e)
      nil
    end

    def instrument_warning(message, xml_node)
      instrument('apply.import_warnings', message: message, xml_node: xml_node)
    end

    def logger_enabled?
      TariffSynchronizer.cds_logger_enabled
    end
  end
end
