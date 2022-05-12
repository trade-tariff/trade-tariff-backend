RSpec.describe CdsImporter::EntityMapper::MeursingHeadingTextMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'meursingTablePlanId' => '01',
        'meursingHeading' => {
          'sid' => '3084',
          'validityEndDate' => '1996-06-14T23:59:59',
          'validityStartDate' => '1991-06-01T00:00:00',
          'meursingHeadingNumber' => '20',
          'rowColumnCode' => '1',
          'meursingHeadingText' => {
            'language' => { 'languageId' => 'EN' },
            'description' => 'Hari Seldon',
            'metainfo' => {
              'opType' => 'U',
              'transactionDate' => '2016-08-21T19:21:46',
            },
          },
          'metainfo' => {
            'opType' => 'C',
            'transactionDate' => '2016-07-27T09:20:15',
          },
        },
      }
    end

    let(:expected_values) do
      {
        operation: 'U',
        operation_date: Date.parse('2016-08-21'),
        meursing_table_plan_id: '01',
        meursing_heading_number: 20,
        row_column_code: 1,
        language_id: 'EN',
        description: 'Hari Seldon',
      }
    end

    let(:expected_entity_class) { 'MeursingHeadingText' }
    let(:expected_mapping_root) { 'MeursingTablePlan' }
  end
end
