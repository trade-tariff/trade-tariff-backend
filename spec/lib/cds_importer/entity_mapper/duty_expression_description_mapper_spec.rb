RSpec.describe CdsImporter::EntityMapper::DutyExpressionDescriptionMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'sid' => 123_456,
        'dutyExpressionId' => '1234',
        'validityStartDate' => '2017-10-01T00:00:00',
        'validityEndDate' => '2020-09-01T00:00:00',
        'dutyExpressionDescription' => {
          'description' => 'Some description',
          'language' => {
            'languageId' => 'EN',
          },
          'metainfo' => {
            'origin' => 'T',
            'opType' => 'C',
            'transactionDate' => '2016-07-27T09:20:14',
          },
        },
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-09-27T07:26:25',
        },
      }
    end
    let(:expected_values) do
      {
        operation: 'C',
        operation_date: Date.parse('2016-07-27'),
        duty_expression_id: '1234',
        language_id: 'EN',
        description: 'Some description',
      }
    end

    let(:expected_entity_class) { 'DutyExpressionDescription' }
    let(:expected_mapping_root) { 'DutyExpression' }
  end
end
