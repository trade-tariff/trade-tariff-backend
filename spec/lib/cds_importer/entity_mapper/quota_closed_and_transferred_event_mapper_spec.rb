RSpec.describe CdsImporter::EntityMapper::QuotaClosedAndTransferredEventMapper do
  let(:xml_node) do
    {
      'sid' => 20_142,
      'validityStartDate' => current_definition_validity_start_date,
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
          'validityStartDate' => target_definition_validity_start_date,
          'quotaOrderNumber' => {
            'hjid' => 10_645_458,
            'sid' => 20_142,
            'quotaOrderNumberId' => '58001',
            'validityStartDate' => '2021-01-01T00:00:00',
          },
        },
        'transferredAmount' => 86_055_072.137,
      },
    }
  end
  let(:current_definition_validity_start_date) { '2022-07-01T00:00:00' }
  let(:target_definition_validity_start_date) { '2022-07-01T00:00:00' }

  it_behaves_like 'an entity mapper', 'QuotaClosedAndTransferredEvent', 'QuotaDefinition' do
    let(:expected_values) do
      {
        operation: 'C',
        operation_date: Date.parse('2022-10-28'),
        quota_definition_sid: 20_142,
        occurrence_timestamp: Time.zone.parse('2022-10-28T13:03:00'),
        target_quota_definition_sid: 21_143,
        transferred_amount: 86_055_072.137,
        closing_date: Date.parse('2022-10-28'),
      }
    end
  end

  describe '#import' do
    subject(:entity_mapper) { CdsImporter::EntityMapper.new('QuotaDefinition', xml_node) }

    context 'when the target quota definition is a newer quota definition' do
      let(:current_definition_validity_start_date) { '2022-07-01T00:00:00' }
      let(:target_definition_validity_start_date) { '2022-08-01T00:00:00' }

      it { expect { entity_mapper.import }.to change(QuotaClosedAndTransferredEvent, :count) }
    end

    context 'when the target quota definition has the same start date' do
      let(:current_definition_validity_start_date) { '2022-07-01T00:00:00' }
      let(:target_definition_validity_start_date) { '2022-07-01T00:00:00' }

      it { expect { entity_mapper.import }.not_to change(QuotaClosedAndTransferredEvent, :count) }
    end

    context 'when the target quota definition is an older quota definition ' do
      let(:current_definition_validity_start_date) { '2022-07-01T00:00:00' }
      let(:target_definition_validity_start_date) { '2022-06-01T00:00:00' }

      it { expect { entity_mapper.import }.not_to change(QuotaClosedAndTransferredEvent, :count) }
    end
  end
end
