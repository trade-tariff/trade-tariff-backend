RSpec.describe CdsImporter::EntityMapper::QuotaDefinitionMapper do
  let(:xml_node) do
    {
      'sid' => '12113',
      'volume' => '30.000',
      'initialVolume' => '30.000',
      'maximumPrecision' => '3',
      'criticalThreshold' => '75',
      'criticalState' => 'N',
      'description' => 'some description',
      'validityStartDate' => '1970-01-01T00:00:00',
      'validityEndDate' => '1972-01-01T00:00:00',
      'quotaOrderNumber' => {
        'sid' => '1485',
        'quotaOrderNumberId' => '092607',
      },
      'measurementUnit' => {
        'measurementUnitCode' => 'KGM',
      },
      'measurementUnitQualifier' => {
        'measurementUnitQualifierCode' => 'X',
      },
      'monetaryUnit' => {
        'monetaryUnitCode' => 'EUR',
      },
      'metainfo' => {
        'opType' => 'U',
        'transactionDate' => '2017-06-29T20:04:37',
      },
    }
  end

  it_behaves_like 'an entity mapper', 'QuotaDefinition', 'QuotaDefinition' do
    let(:expected_values) do
      {
        validity_start_date: Time.zone.parse('1970-01-01T00:00:00.000Z'),
        validity_end_date: Time.zone.parse('1972-01-01T00:00:00.000Z'),
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        quota_definition_sid: 12_113,
        quota_order_number_sid: 1485,
        quota_order_number_id: '092607',
        volume: 30,
        initial_volume: 30,
        maximum_precision: 3,
        critical_state: 'N',
        critical_threshold: 75,
        monetary_unit_code: 'EUR',
        measurement_unit_code: 'KGM',
        measurement_unit_qualifier_code: 'X',
        description: 'some description',
      }
    end
  end

  describe '#import' do
    subject(:entity_mapper) { CdsImporter::EntityMapper.new('QuotaDefinition', xml_node) }

    let(:change_definition_events_count) do
      change do
        QuotaClosedAndTransferredEvent.where(quota_definition_sid: xml_node['sid']).count
      end
    end

    context 'when there is already a quotaClosedAndTransferredEvent but none in the xml node' do
      before { create(:quota_closed_and_transferred_event, quota_definition_sid: xml_node['sid']) }

      it { expect { entity_mapper.import }.to change_definition_events_count.by(-1) }
    end

    context 'when there is already a quotaClosedAndTransferredEvent and one in the xml node' do
      subject(:entity_mapper) do
        xml_node = xml_node.merge(
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

        CdsImporter::EntityMapper.new('QuotaDefinition', xml_node)
      end

      before { create(:quota_closed_and_transferred_event, quota_definition_sid: xml_node['sid']) }

      it { expect { entity_mapper.import }.not_to change_definition_events_count }

      it 'imports the new event' do
        entity_mapper.import

        expect(QuotaClosedAndTransferredEvent.find(target_quota_definition_sid: 21_143)).to be_present
      end
    end
  end
end
