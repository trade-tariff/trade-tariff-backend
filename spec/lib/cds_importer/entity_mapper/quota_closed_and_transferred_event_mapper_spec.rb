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
        transferred_amount: 769_858,
        closing_date: Date.parse('2022-05-03'),
      }
    end
  end

  describe '#import' do
    subject(:entity_mapper) { CdsImporter::EntityMapper.new('QuotaDefinition', xml_node) }

    context 'when the transfer target definition is newer' do
      it 'imports the transfer event' do
        yielded_objects = []

        entity_mapper.import do |entity|
          yielded_objects << entity
        end

        expect(yielded_objects.map(&:instance).map { |obj| { obj.class.name.to_sym => obj.values } })
          .to include(
            { QuotaClosedAndTransferredEvent: hash_including(quota_definition_sid: 21_321, target_quota_definition_sid: 21_322) },
          )
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

      it 'imports the transfer event' do
        yielded_objects = []

        entity_mapper.import do |entity|
          yielded_objects << entity
        end

        expect(yielded_objects.map(&:instance).map { |obj| { obj.class.name.to_sym => obj.values } })
          .to include(
            { QuotaClosedAndTransferredEvent: hash_including(quota_definition_sid: 21_321, target_quota_definition_sid: 21_322) },
          )
      end
    end
  end
end
