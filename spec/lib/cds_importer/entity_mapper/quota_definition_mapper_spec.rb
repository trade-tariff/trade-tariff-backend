RSpec.describe CdsImporter::EntityMapper::QuotaDefinitionMapper do
  let(:xml_node) do
    {
      'hjid' => '11530155',
      'metainfo' => {
        'opType' => operation,
        'origin' => 'T',
        'status' => 'L',
        'transactionDate' => '2022-07-04T16:27:01',
      },
      'sid' => '21891',
      'criticalState' => 'N',
      'criticalThreshold' => '90',
      'initialVolume' => '264000',
      'maximumPrecision' => '3',
      'validityEndDate' => '2023-06-30T23:59:59',
      'validityStartDate' => '2022-07-01T00:00:00',
      'volume' => '264000',
      'measurementUnit' => {
        'hjid' => '10707',
        'measurementUnitCode' => 'KGM',
      },
      'quotaBalanceEvent' => {
        'hjid' => '11925094',
        'metainfo' => {
          'opType' => operation,
          'origin' => 'T',
          'status' => 'L',
          'transactionDate' => '2022-07-04T16:27:01',
        },
        'importedAmount' => '15195',
        'lastImportDateInAllocation' => '2022-07-01T00:00:00',
        'newBalance' => '248805',
        'occurrenceTimestamp' => '2022-07-04T14:48:00',
        'oldBalance' => '264000',
      },
      'quotaCriticalEvent' => {
        'hjid' => '11751144',
        'metainfo' => {
          'opType' => operation,
          'origin' => 'T',
          'status' => 'L',
          'transactionDate' => '2022-03-23T17:31:08',
        },
        'criticalState' => 'Y',
        'criticalStateChangeDate' => '2022-03-23T00:00:00',
        'occurrenceTimestamp' => '2022-03-23T13:00:00',
      },
      'quotaExhaustionEvent' => {
        'hjid' => '11717110',
        'metainfo' => {
          'opType' => operation,
          'origin' => 'T',
          'status' => 'L',
          'transactionDate' => '2022-02-10T18:02:05',
        },
        'exhaustionDate' => '2022-02-09T00:00:00',
        'occurrenceTimestamp' => '2022-02-10T13:00:00',
      },
      'quotaReopeningEvent' => {
        'hjid' => '11757076',
        'metainfo' => {
          'opType' => operation,
          'origin' => 'T',
          'status' => 'L',
          'transactionDate' => '2022-03-24T14:30:01',
        },
        'occurrenceTimestamp' => '2022-03-24T11:56:00',
        'reopeningDate' => '2022-03-24T00:00:00',
      },
      'quotaSuspensionPeriod' => {
        'hjid' => '10731998',
        'metainfo' => {
          'opType' => operation,
          'origin' => 'T',
          'status' => 'L',
          'transactionDate' => '2020-11-29T16:32:54',
        },
        'sid' => '2000',
        'suspensionEndDate' => '2022-05-31T23:59:59',
        'suspensionStartDate' => '2022-05-01T00:00:00',
      },
      'quotaUnsuspensionEvent' => {
        'hjid' => '11883116',
        'metainfo' => {
          'opType' => operation,
          'origin' => 'T',
          'status' => 'L',
          'transactionDate' => '2022-05-31T22:02:03',
        },
        'occurrenceTimestamp' => '2022-05-31T03:18:00',
        'unsuspensionDate' => '2022-06-01T00:00:00',
      },
      'quotaOrderNumber' => {
        'hjid' => '11005093',
        'sid' => '20777',
        'quotaOrderNumberId' => '050096',
        'validityStartDate' => '2021-01-01T00:00:00',
      },
      'quotaAssociation' => {
        'hjid' => '11851337',
        'metainfo' => {
          'opType' => operation,
          'origin' => 'T',
          'status' => 'L',
          'transactionDate' => '2022-05-04T18:02:01',
        },
        'coefficient' => '1',
        'relationType' => 'EQ',
        'subQuotaDefinition' => {
          'hjid' => '11272625',
          'sid' => '21741',
          'validityStartDate' => '2022-01-01T00:00:00',
          'quotaOrderNumber' => {
            'hjid' => '11271659',
            'sid' => '20952',
            'quotaOrderNumberId' => '058041',
            'validityStartDate' => '2021-07-01T00:00:00',
          },
        },
      },
      'quotaClosedAndTransferredEvent' => {
        'hjid' => '11851504',
        'metainfo' => {
          'opType' => operation,
          'origin' => 'T',
          'status' => 'L',
          'transactionDate' => '2022-05-05T18:02:08',
        },
        'closingDate' => '2022-05-04T00:00:00',
        'occurrenceTimestamp' => '2022-05-04T20:46:00',
        'targetQuotaDefinition' => {
          'hjid' => '11272625',
          'sid' => '21741',
          'validityStartDate' => '2022-01-01T00:00:00',
          'quotaOrderNumber' => {
            'hjid' => '11271659',
            'sid' => '20952',
            'quotaOrderNumberId' => '058041',
            'validityStartDate' => '2021-07-01T00:00:00',
          },
        },
        'transferredAmount' => '9243041.052',
      },
    }
  end

  let(:operation) { 'U' }

  it_behaves_like 'an entity mapper', 'QuotaDefinition', 'QuotaDefinition' do
    let(:expected_values) do
      {
        validity_start_date: '2022-07-01T00:00:00.000Z',
        validity_end_date: '2023-06-30T23:59:59.000Z',
        operation: 'U',
        operation_date: Date.parse('2022-07-04'),
        quota_definition_sid: 21_891,
        quota_order_number_sid: 20_777,
        quota_order_number_id: '050096',
        volume: 264_000,
        initial_volume: 264_000,
        maximum_precision: 3,
        critical_state: 'N',
        critical_threshold: 90,
        monetary_unit_code: nil,
        measurement_unit_code: 'KGM',
        measurement_unit_qualifier_code: nil,
        description: nil,
      }
    end
  end

  describe '#import' do
    subject(:entity_mapper) { CdsImporter::EntityMapper.new('QuotaDefinition', xml_node) }

    context 'when the quota definition is being updated' do
      let(:operation) { 'U' }

      it_behaves_like 'an entity mapper update operation', QuotaDefinition
      it_behaves_like 'an entity mapper update operation', QuotaAssociation
      it_behaves_like 'an entity mapper update operation', QuotaBalanceEvent
      it_behaves_like 'an entity mapper update operation', QuotaCriticalEvent
      it_behaves_like 'an entity mapper update operation', QuotaExhaustionEvent
      it_behaves_like 'an entity mapper update operation', QuotaReopeningEvent
      it_behaves_like 'an entity mapper update operation', QuotaSuspensionPeriod
      it_behaves_like 'an entity mapper update operation', QuotaUnsuspensionEvent

      # TODO: We need real examples of these - they haven't appeared in an XML file yet
      # it_behaves_like 'an entity mapper update operation', QuotaBlockingPeriod
      # it_behaves_like 'an entity mapper update operation', QuotaUnblockingEvent
    end

    context 'when the quota definition is being created' do
      let(:operation) { 'C' }

      it_behaves_like 'an entity mapper create operation', QuotaDefinition
      it_behaves_like 'an entity mapper create operation', QuotaAssociation
      it_behaves_like 'an entity mapper create operation', QuotaBalanceEvent
      it_behaves_like 'an entity mapper create operation', QuotaCriticalEvent
      it_behaves_like 'an entity mapper create operation', QuotaExhaustionEvent
      it_behaves_like 'an entity mapper create operation', QuotaReopeningEvent
      it_behaves_like 'an entity mapper create operation', QuotaSuspensionPeriod
      it_behaves_like 'an entity mapper create operation', QuotaUnsuspensionEvent

      # TODO: We need real examples of these - they haven't appeared in an XML file yet
      # it_behaves_like 'an entity mapper create operation', QuotaBlockingPeriod
      # it_behaves_like 'an entity mapper create operation', QuotaUnblockingEvent
    end

    context 'when the quota definition is being deleted' do
      before do
        create(:quota_definition, quota_definition_sid: '21891')
        create(:quota_association, main_quota_definition_sid: '21891', sub_quota_definition_sid: '21741')
        create(:quota_balance_event, quota_definition_sid: '21891', occurrence_timestamp: '2022-07-04T14:48:00')
        create(:quota_critical_event, quota_definition_sid: '21891', occurrence_timestamp: '2022-03-23T13:00:00')
        create(:quota_exhaustion_event, quota_definition_sid: '21891', occurrence_timestamp: '2022-02-10T13:00:00')
        create(:quota_reopening_event, quota_definition_sid: '21891', occurrence_timestamp: '2022-03-24T11:56:00')
        create(:quota_suspension_period, quota_definition_sid: '21891', quota_suspension_period_sid: '2000')
        create(:quota_unsuspension_event, quota_definition_sid: '21891', occurrence_timestamp: '2022-05-31T03:18:00')
      end

      let(:operation) { 'D' }

      it_behaves_like 'an entity mapper destroy operation', QuotaDefinition
      it_behaves_like 'an entity mapper destroy operation', QuotaAssociation
      it_behaves_like 'an entity mapper destroy operation', QuotaBalanceEvent
      it_behaves_like 'an entity mapper destroy operation', QuotaCriticalEvent
      it_behaves_like 'an entity mapper destroy operation', QuotaExhaustionEvent
      it_behaves_like 'an entity mapper destroy operation', QuotaReopeningEvent
      it_behaves_like 'an entity mapper destroy operation', QuotaSuspensionPeriod
      it_behaves_like 'an entity mapper destroy operation', QuotaUnsuspensionEvent

      # TODO: We need real examples of these - they haven't appeared in an XML file yet
      # it_behaves_like 'an entity mapper destroy operation', QuotaBlockingPeriod
      # it_behaves_like 'an entity mapper destroy operation', QuotaUnblockingEvent
    end

    context 'when there is already a quotaClosedAndTransferredEvent and one in the xml node' do
      subject(:entity_mapper) do
        node = xml_node.dup.merge(
          'quotaClosedAndTransferredEvent' => {
            'hjid' => 12_172_305,
            'metainfo' => {
              'opType' => 'C',
              'origin' => 'T',
              'status' => 'L',
              'transactionDate' => '2022-10-28T18:02:02',
            },
            'closingDate' => '2022-10-28T00:00:00',
            'occurrenceTimestamp' => '2022-10-28T13:03:00',
            'targetQuotaDefinition' => {
              'hjid' => 11_272_027,
              'sid' => 21_143,
              'validityStartDate' => '2022-10-28T18:02:02',
              'quotaOrderNumber' => {
                'hjid' => 10_645_458,
                'sid' => 20_142,
                'quotaOrderNumberId' => '58001',
                'validityStartDate' => '2021-01-01T00:00:00',
              },
            },
            'transferredAmount' => 86_055_072.137,
          },
        )

        CdsImporter::EntityMapper.new('QuotaDefinition', node)
      end

      before { create(:quota_closed_and_transferred_event, quota_definition_sid: xml_node['sid']) }

      it 'imports the new event' do
        yielded_objects = []

        entity_mapper.build do |entity|
          yielded_objects << entity
        end

        expect(yielded_objects.map(&:instance).map { |obj| { obj.class.name.to_sym => obj.values } })
          .to include(
            { QuotaClosedAndTransferredEvent: hash_including(target_quota_definition_sid: 21_143) },
          )
      end
    end
  end
end
