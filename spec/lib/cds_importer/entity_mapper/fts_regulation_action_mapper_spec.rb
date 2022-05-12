RSpec.describe CdsImporter::EntityMapper::FtsRegulationActionMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'sid' => '1277',
        'approvedFlag' => '1',
        'fullTemporaryStopRegulationId' => '11122',
        'regulationRoleType' => {
          'regulationRoleTypeId' => '6',
        },
        'ftsRegulationAction' => {
          'sid' => '1127',
          'stoppedRegulationId' => '112233',
          'stoppedRegulationRole' => '5',
          'metainfo' => {
            'opType' => 'U',
            'transactionDate' => '2017-07-26T19:18:31',
          },
        },
        'metainfo' => {
          'opType' => 'C',
          'transactionDate' => '2016-07-27T09:18:51',
        },
      }
    end

    let(:expected_values) do
      {
        operation: 'U',
        operation_date: Date.parse('2017-07-26'),
        fts_regulation_role: 6,
        fts_regulation_id: '11122',
        stopped_regulation_role: 5,
        stopped_regulation_id: '112233',
      }
    end

    let(:expected_entity_class) { 'FtsRegulationAction' }
    let(:expected_mapping_root) { 'FullTemporaryStopRegulation' }
  end
end
