RSpec.describe CdsImporter::EntityMapper::MeasureActionMapper do
  it_behaves_like 'an entity mapper', 'MeasureAction', 'MeasureAction' do
    let(:xml_node) do
      {
        'actionCode' => '29',
        'validityStartDate' => '1970-01-01T00:00:00',
        'validityEndDate' => '1972-01-01T00:00:00',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: Time.zone.parse('1970-01-01T00:00:00.000Z'),
        validity_end_date: Time.zone.parse('1972-01-01T00:00:00.000Z'),
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        action_code: '29',
      }
    end
  end
end
