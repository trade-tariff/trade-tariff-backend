RSpec.describe CdsImporter::EntityMapper::MeasureConditionCodeMapper do
  it_behaves_like 'an entity mapper', 'MeasureConditionCode', 'MeasureConditionCode' do
    let(:xml_node) do
      {
        'conditionCode' => 'A',
        'validityStartDate' => '1970-01-01T00:00:00',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: Time.zone.parse('1970-01-01T00:00:00.000Z'),
        validity_end_date: nil,
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        condition_code: 'A',
      }
    end
  end
end
