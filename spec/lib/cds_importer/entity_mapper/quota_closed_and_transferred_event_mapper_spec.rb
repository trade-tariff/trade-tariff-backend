RSpec.describe CdsImporter::EntityMapper::QuotaClosedAndTransferredEventMapper do
  let(:xml_node) do
    {
      'sid' => '21321',
      'validityStartDate' => '2022-01-01T00:00:00',
      'quotaClosedAndTransferredEvent' => [
        { # Valid newer dated transfer event - imported
          'metainfo' => { 'opType' => 'C', 'transactionDate' => '2022-05-03T18:02:08' },
          'closingDate' => '2022-05-03T00:00:00',
          'occurrenceTimestamp' => '2022-05-03T13:04:00',
          'targetQuotaDefinition' => {
            'sid' => '21322',
            'validityStartDate' => '2022-04-01T00:00:00', # newer date
          },
          'transferredAmount' => '769858',
        },
        { # Invalid older dated transfer event - not imported
          'metainfo' => { 'opType' => 'C', 'transactionDate' => '2022-01-31T17:38:16' },
          'closingDate' => '2022-01-31T00:00:00',
          'occurrenceTimestamp' => '2022-01-31T13:33:00',
          'targetQuotaDefinition' => {
            'sid' => '21320',
            'validityStartDate' => '2021-10-01T00:00:00', # older date
          },
          'transferredAmount' => '3629563.69',
        },
        { # Invalid same dated transfer event - not imported
          'metainfo' => { 'opType' => 'C', 'transactionDate' => '2022-05-03T18:02:08' },
          'closingDate' => '2022-05-03T00:00:00',
          'occurrenceTimestamp' => '2022-05-03T13:04:00',
          'targetQuotaDefinition' => {
            'sid' => '21323',
            'validityStartDate' => '2022-01-01T00:00:00', # same date
          },
          'transferredAmount' => '112312312.493',
        },
      ],
    }
  end

  it_behaves_like 'an entity mapper', 'QuotaClosedAndTransferredEvent', 'QuotaDefinition' do
    let(:expected_values) do
      {
        operation: 'C',
        operation_date: Date.parse('2022-05-03'),
        quota_definition_sid: 21_321,
        occurrence_timestamp: Time.zone.parse('2022-05-03T13:04:00'),
        target_quota_definition_sid: 21_322,
        transferred_amount: 769_858.493,
        closing_date: Date.parse('2022-05-03'),
      }
    end
  end

  describe '#import' do
    subject(:entity_mapper) { CdsImporter::EntityMapper.new('QuotaDefinition', xml_node) }

    it { expect { entity_mapper.import }.to change(QuotaClosedAndTransferredEvent, :count).by(1) }

    context 'when the transfer target definition is newer' do
      let(:target_definition_transfer_event) do # imported
        QuotaClosedAndTransferredEvent.where(
          quota_definition_sid: '21321',
          target_quota_definition_sid: '21322',
        )
      end

      it 'imports the transfer event' do
        entity_mapper.import

        expect(target_definition_transfer_event).to be_present
      end
    end

    context 'when the transfer target definition is older' do
      let(:target_definition_transfer_event) do
        QuotaClosedAndTransferredEvent.where(
          quota_definition_sid: '21321',
          target_quota_definition_sid: '21320',
        )
      end

      it 'does not import the transfer event' do
        entity_mapper.import

        expect(target_definition_transfer_event).not_to be_present
      end
    end

    context 'when the transfer target definition is for the same date' do
      let(:target_definition_transfer_event) do
        QuotaClosedAndTransferredEvent.where(
          quota_definition_sid: '21321',
          target_quota_definition_sid: '21323',
        )
      end

      it 'does not import the transfer event' do
        entity_mapper.import

        expect(target_definition_transfer_event).not_to be_present
      end
    end

    context 'when there is only one transfer event in the xml node' do
      let(:xml_node) do
        {
          'sid' => '21321',
          'validityStartDate' => '2022-01-01T00:00:00',
          'quotaClosedAndTransferredEvent' => {
            'metainfo' => { 'opType' => 'C', 'transactionDate' => '2022-05-03T18:02:08' },
            'closingDate' => '2022-05-03T00:00:00',
            'occurrenceTimestamp' => '2022-05-03T13:04:00',
            'targetQuotaDefinition' => {
              'sid' => '21322',
              'validityStartDate' => '2022-04-01T00:00:00', # newer date
            },
            'transferredAmount' => '769858.493',
          },
        }
      end

      let(:target_definition_transfer_event) do
        QuotaClosedAndTransferredEvent.where(
          quota_definition_sid: '21321',
          target_quota_definition_sid: '21322',
        )
      end

      it 'imports the transfer event' do
        entity_mapper.import

        expect(target_definition_transfer_event).to be_present
      end
    end
  end
end
