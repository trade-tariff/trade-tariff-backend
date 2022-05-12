RSpec.describe CdsImporter::EntityMapper::MeursingSubheadingMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'meursingTablePlanId' => '01',
        'validityStartDate' => '1988-01-01T00:00:00',
        'meursingHeading' => {
          'sid' => '1054',
          'validityEndDate' => '1997-07-11T22:59:59',
          'validityStartDate' => '1999-09-04T00:00:00',
          'meursingHeadingNumber' => '20',
          'rowColumnCode' => '1',
          'metainfo' => {
            'opType' => 'C',
            'transactionDate' => '2016-08-27T10:20:15',
          },
          'meursingSubheading' => {
            'sid' => '3084',
            'validityEndDate' => '1996-06-14T23:59:59',
            'validityStartDate' => '1991-06-01T00:00:00',
            'subheadingSequenceNumber' => '11',
            'description' => 'Some text.',
            'metainfo' => {
              'opType' => 'U',
              'transactionDate' => '2016-07-27T09:20:17',
            },
          },
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: Time.parse('1991-06-01T00:00:00.000Z'),
        validity_end_date: Time.parse('1996-06-14T23:59:59.000Z'),
        operation: 'U',
        operation_date: Date.parse('2016-07-27'),
        meursing_table_plan_id: '01',
        meursing_heading_number: 20,
        row_column_code: 1,
        subheading_sequence_number: 11,
        description: 'Some text.',
      }
    end

    let(:expected_entity_class) { 'MeursingSubheading' }
    let(:expected_mapping_root) { 'MeursingTablePlan' }
  end
end
