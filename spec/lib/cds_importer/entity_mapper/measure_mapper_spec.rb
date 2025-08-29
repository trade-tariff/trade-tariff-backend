RSpec.describe CdsImporter::EntityMapper::MeasureMapper do
  let(:cutoff) { Date.tomorrow }

  before do
    allow(TradeTariffBackend).to receive(:implicit_deletion_cutoff).and_return(cutoff)
  end

  it_behaves_like 'an entity mapper', 'Measure', 'Measure' do
    let(:xml_node) do
      {
        'sid' => '12348',
        'validityStartDate' => '1970-01-01T00:00:00',
        'validityEndDate' => '1972-01-01T00:00:00',
        'measureType' => { 'measureTypeId' => '468' },
        'geographicalArea' => { 'sid' => '11881', 'geographicalAreaId' => '1011' },
        'goodsNomenclature' => { 'sid' => '22118', 'goodsNomenclatureItemId' => '0102900500' },
        'measureGeneratingRegulationRole' => { 'regulationRoleTypeId' => '1' },
        'measureGeneratingRegulationId' => 'IYY99990',
        'justificationRegulationRole' => { 'regulationRoleTypeId' => '1' },
        'justificationRegulationId' => 'IYY99990',
        'stoppedFlag' => '0',
        'ordernumber' => '094281',
        'additionalCode' => {
          'sid' => '11822',
          'additionalCodeCode' => '912',
          'additionalCodeType' => { 'additionalCodeTypeId' => '8' },
        },
        'reductionIndicator' => '35',
        'exportRefundNomenclature' => { 'sid' => '19911' },
        'metainfo' => {
          'opType' => 'U',
          'origin' => 'N',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: Time.zone.parse('1970-01-01T00:00:00.000Z'),
        validity_end_date: Time.zone.parse('1972-01-01T00:00:00.000Z'),
        national: true,
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        measure_sid: 12_348,
        measure_type_id: '468',
        geographical_area_id: '1011',
        geographical_area_sid: 11_881,
        goods_nomenclature_item_id: '0102900500',
        goods_nomenclature_sid: 22_118,
        measure_generating_regulation_role: 1,
        measure_generating_regulation_id: 'IYY99990',
        justification_regulation_role: 1,
        justification_regulation_id: 'IYY99990',
        stopped_flag: false,
        ordernumber: '094281',
        additional_code_type_id: '8',
        additional_code_id: '912',
        additional_code_sid: 11_822,
        reduction_indicator: 35,
        export_refund_nomenclature_sid: 19_911,
      }
    end
  end

  describe '#import' do
    subject(:entity_mapper) { CdsImporter::EntityMapper.new('Measure', xml_node) }

    let(:xml_node) do
      {
        'sid' => '12348',
        'validityStartDate' => '1970-01-01T00:00:00',
        'validityEndDate' => '1972-01-01T00:00:00',
        'measureType' => { 'measureTypeId' => '468' },
        'geographicalArea' => { 'sid' => '11881', 'geographicalAreaId' => '1011' },
        'goodsNomenclature' => { 'sid' => '22118', 'goodsNomenclatureItemId' => '0102900500' },
        'measureGeneratingRegulationRole' => { 'regulationRoleTypeId' => '1' },
        'measureGeneratingRegulationId' => 'IYY99990',
        'justificationRegulationRole' => { 'regulationRoleTypeId' => '1' },
        'justificationRegulationId' => 'IYY99990',
        'stoppedFlag' => '0',
        'ordernumber' => '094281',
        'additionalCode' => {
          'sid' => '11822',
          'additionalCodeCode' => '912',
          'additionalCodeType' => { 'additionalCodeTypeId' => '8' },
        },
        'reductionIndicator' => '35',
        'exportRefundNomenclature' => { 'sid' => '19911' },
        'metainfo' => {
          'opType' => operation,
          'origin' => 'N',
          'transactionDate' => '2017-06-29T20:04:37',
        },
        'footnoteAssociationMeasure' => {
          'footnote' => {
            'footnoteId' => '08',
            'footnoteType' => {
              'footnoteTypeId' => '06',
            },
          },
          'metainfo' => {
            'opType' => operation,
            'origin' => 'N',
            'transactionDate' => '2017-08-27T19:23:57',
          },
        },
        'measureComponent' => {
          'dutyAmount' => '12.34',
          'dutyExpression' => { 'dutyExpressionId' => '01' },
          'monetaryUnit' => { 'monetaryUnitCode' => 'EUR' },
          'measurementUnit' => { 'measurementUnitCode' => 'DTN' },
          'measurementUnitQualifier' => { 'measurementUnitQualifierCode' => 'A' },
          'metainfo' => {
            'opType' => operation,
            'transactionDate' => '2017-06-29T20:04:37',
          },
        },
        'measureCondition' => [
          {
            'sid' => '3321',
            'conditionDutyAmount' => '12.34',
            'conditionSequenceNumber' => '123',
            'measureConditionComponent' => [
              {
                'dutyExpression' => { 'dutyExpressionId' => '01' },
                'dutyAmount' => '23.1',
                'monetaryUnit' => { 'monetaryUnitCode' => 'USD' },
                'measurementUnit' => { 'measurementUnitCode' => 'ASD' },
                'measurementUnitQualifier' => { 'measurementUnitQualifierCode' => 'A' },
                'metainfo' => {
                  'opType' => operation,
                  'transactionDate' => '2017-06-29T20:04:37',
                },
              },
            ],
            'monetaryUnit' => { 'monetaryUnitCode' => 'EUR' },
            'measurementUnit' => { 'measurementUnitCode' => 'DTN' },
            'measurementUnitQualifier' => { 'measurementUnitQualifierCode' => 'B' },
            'metainfo' => {
              'opType' => operation,
              'transactionDate' => '2017-06-29T20:04:37',
            },
          },
        ],
        'measureExcludedGeographicalArea' => {
          'geographicalArea' => {
            'sid' => '11993',
            'geographicalAreaId' => '1101',
          },
          'metainfo' => {
            'opType' => operation,
            'transactionDate' => '2017-07-14T21:34:15',
          },
        },
        'measurePartialTemporaryStop' => {
          'sid' => '22134',
          'validityStartDate' => '1971-03-03T00:00:00',
          'validityEndDate' => '2018-02-01T00:00:00',
          'partialTemporaryStopRegulationId' => 'R1312020',
          'partialTemporaryStopRegulationOfficialjournalNumber' => 'L 321',
          'partialTemporaryStopRegulationOfficialjournalPage' => '1',
          'abrogationRegulationId' => 'R1312021',
          'abrogationRegulationOfficialjournalNumber' => 'L 323',
          'abrogationRegulationOfficialjournalPage' => '2',
          'metainfo' => {
            'opType' => operation,
            'transactionDate' => '2017-07-25T21:03:21',
          },
        },
        'filename' => "tariff_dailyExtract_v1_#{Time.zone.today.strftime('%Y%m%d')}T235959.gzip",
      }
    end

    context 'when implictly deleting secondary entities before a cutoff' do
      before do
        create(
          :measure,
          :with_footnote_association,
          :with_measure_excluded_geographical_area,
          measure_sid: '12348',
        )
      end

      let(:cutoff) { Date.tomorrow }
      let(:operation) { 'C' }

      it 'removes the old footnote associations' do
        old = FootnoteAssociationMeasure.last.oid
        entity_mapper.build
        expect(FootnoteAssociationMeasure.pluck(:oid)).not_to include(old)
      end

      it 'removes the old measure excluded geographical areas' do
        old = MeasureExcludedGeographicalArea.last.oid
        entity_mapper.build
        MeasureExcludedGeographicalArea.refresh!
        expect(MeasureExcludedGeographicalArea.pluck(:oid)).not_to include(old)
      end
    end

    context 'when implictly deleting secondary entities after a cutoff' do
      before do
        create(
          :measure,
          :with_footnote_association,
          :with_measure_excluded_geographical_area,
          measure_sid: '12348',
        )
      end

      let(:cutoff) { Time.zone.today }
      let(:operation) { 'C' }

      it 'does not remove the old footnote associations' do
        old = FootnoteAssociationMeasure.last.oid
        entity_mapper.build
        expect(FootnoteAssociationMeasure.pluck(:oid)).to include(old)
      end

      it 'does not remove the old measure excluded geographical areas' do
        old = MeasureExcludedGeographicalArea.last.oid
        entity_mapper.build
        expect(MeasureExcludedGeographicalArea.pluck(:oid)).to include(old)
      end
    end

    context 'when the measure is being updated' do
      let(:operation) { 'U' }

      it_behaves_like 'an entity mapper update operation', Measure
      it_behaves_like 'an entity mapper update operation', FootnoteAssociationMeasure
      it_behaves_like 'an entity mapper update operation', MeasureComponent
      it_behaves_like 'an entity mapper update operation', MeasureCondition
      it_behaves_like 'an entity mapper update operation', MeasureConditionComponent
      it_behaves_like 'an entity mapper update operation', MeasureExcludedGeographicalArea
      it_behaves_like 'an entity mapper update operation', MeasurePartialTemporaryStop
    end

    context 'when the measure is being created' do
      let(:operation) { 'C' }

      it_behaves_like 'an entity mapper create operation', Measure
      it_behaves_like 'an entity mapper create operation', FootnoteAssociationMeasure
      it_behaves_like 'an entity mapper create operation', MeasureComponent
      it_behaves_like 'an entity mapper create operation', MeasureCondition
      it_behaves_like 'an entity mapper create operation', MeasureConditionComponent
      it_behaves_like 'an entity mapper create operation', MeasureExcludedGeographicalArea
      it_behaves_like 'an entity mapper create operation', MeasurePartialTemporaryStop
    end

    context 'when the measure is being deleted' do
      before do
        create(
          :measure,
          measure_sid: '12348',
        )
        create(:footnote_association_measure, measure_sid: '12348', footnote_type_id: '06', footnote_id: '08')
        create(:measure_component, measure_sid: '12348', duty_expression_id: '01')
        create(:measure_condition, measure_sid: '12348', measure_condition_sid: '3321')
        create(:measure_condition_component, measure_condition_sid: '3321', duty_expression_id: '01')
        create(:measure_excluded_geographical_area, measure_sid: '12348', geographical_area_sid: '11993')
        create(:measure_partial_temporary_stop, measure_sid: '12348', partial_temporary_stop_regulation_id: 'R1312020')
      end

      let(:operation) { 'D' }

      it_behaves_like 'an entity mapper destroy operation', Measure
      it_behaves_like 'an entity mapper destroy operation', FootnoteAssociationMeasure
      it_behaves_like 'an entity mapper destroy operation', MeasureComponent
      it_behaves_like 'an entity mapper destroy operation', MeasureCondition
      it_behaves_like 'an entity mapper destroy operation', MeasureConditionComponent
      it_behaves_like 'an entity mapper destroy operation', MeasureExcludedGeographicalArea
      it_behaves_like 'an entity mapper destroy operation', MeasurePartialTemporaryStop
    end
  end
end
