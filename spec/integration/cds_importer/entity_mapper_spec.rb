RSpec.describe CdsImporter::EntityMapper do
  subject(:entity_mapper) { described_class.new('AdditionalCode', xml_node) }

  let(:xml_node) do
    {
      'sid' => '3084',
      'additionalCodeCode' => '169',
      'validityEndDate' => '1996-06-14T23:59:59',
      'validityStartDate' => '1991-06-01T00:00:00',
      'additionalCodeType' => {
        'additionalCodeTypeId' => '8',
      },
      'metainfo' => {
        'origin' => 'N',
        'opType' => 'U',
        'transactionDate' => '2016-07-27T09:20:15',
      },
      'filename' => 'test.gzip',
    }
  end

  describe '.applicable_mappers_for' do
    subject(:applicable_mappers_for) { described_class.applicable_mappers_for(key, xml_node) }

    let(:xml_node) do
      {
        'metainfo' => {
          'opType' => operation,
          'origin' => 'N',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      }
    end

    context 'when the key belongs to a mapping root' do
      let(:key) { 'Measure' }
      let(:operation) { 'U' }

      let(:expected_applicable_mappers) do
        [
          an_instance_of(CdsImporter::EntityMapper::MeasureMapper),
          an_instance_of(CdsImporter::EntityMapper::MeasureComponentMapper),
          an_instance_of(CdsImporter::EntityMapper::MeasureConditionMapper),
          an_instance_of(CdsImporter::EntityMapper::FootnoteAssociationMeasureMapper),
          an_instance_of(CdsImporter::EntityMapper::MeasurePartialTemporaryStopMapper),
          an_instance_of(CdsImporter::EntityMapper::MeasureExcludedGeographicalAreaMapper),
          an_instance_of(CdsImporter::EntityMapper::MeasureConditionComponentMapper),
        ]
      end

      it { is_expected.to match_array(expected_applicable_mappers) }
    end

    context 'when the key does not belong to a mapping root' do
      let(:key) { 'ReticulatingSpleens' }
      let(:expected_applicable_mappers) { [] }
      let(:operation) { 'U' }

      it { is_expected.to eq(expected_applicable_mappers) }
    end
  end

  describe '.all_mapping_roots' do
    subject(:all_mapping_roots) { described_class.all_mapping_roots.reject { |mr| mr == 'foo' } }

    let(:expected_mapping_roots) do
      %w[
        AdditionalCode
        AdditionalCodeType
        BaseRegulation
        Certificate
        CertificateType
        CompleteAbrogationRegulation
        DutyExpression
        ExplicitAbrogationRegulation
        Footnote
        FootnoteType
        FullTemporaryStopRegulation
        GeographicalArea
        GoodsNomenclature
        Language
        Measure
        MeasureAction
        MeasureConditionCode
        MeasureType
        MeasureTypeSeries
        MeasurementUnit
        MeasurementUnitQualifier
        MeursingAdditionalCode
        MeursingTablePlan
        ModificationRegulation
        MonetaryExchangePeriod
        MonetaryUnit
        ProrogationRegulation
        QuotaDefinition
        QuotaOrderNumber
        RegulationGroup
        RegulationReplacement
        RegulationRoleType
      ]
    end

    it { is_expected.to eq(expected_mapping_roots) }
  end

  describe '.all_mappers' do
    subject(:all_mappers) { described_class.all_mappers.sort_by(&:name) }

    let(:expected_mappers) do
      [
        CdsImporter::EntityMapper::AdditionalCodeDescriptionMapper,
        CdsImporter::EntityMapper::AdditionalCodeDescriptionPeriodMapper,
        CdsImporter::EntityMapper::AdditionalCodeMapper,
        CdsImporter::EntityMapper::AdditionalCodeTypeDescriptionMapper,
        CdsImporter::EntityMapper::AdditionalCodeTypeMapper,
        CdsImporter::EntityMapper::AdditionalCodeTypeMeasureTypeMapper,
        CdsImporter::EntityMapper::BaseMapper,
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
        CdsImporter::EntityMapper::FootnoteAssociationAdditionalCodeMapper,
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
        CdsImporter::EntityMapper::ProrogationRegulationActionMapper,
        CdsImporter::EntityMapper::ProrogationRegulationMapper,
        CdsImporter::EntityMapper::QuotaAssociationMapper,
        CdsImporter::EntityMapper::QuotaBalanceEventMapper,
        CdsImporter::EntityMapper::QuotaBlockingPeriodMapper,
        CdsImporter::EntityMapper::QuotaClosedAndTransferredEventMapper,
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
      ]
    end

    it { is_expected.to eq(expected_mappers) }
  end
end
