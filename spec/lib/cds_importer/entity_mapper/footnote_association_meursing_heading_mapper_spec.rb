RSpec.describe CdsImporter::EntityMapper::FootnoteAssociationMeursingHeadingMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'meursingTablePlanId' => '2',
        'meursingHeading' => {
          'sid' => '3084',
          'meursingHeadingNumber' => '6',
          'rowColumnCode' => '1',
          'validityEndDate' => '1996-06-14T23:59:59',
          'validityStartDate' => '1991-06-01T00:00:00',
          'footnoteAssociationMeursingHeading' => {
            'validityEndDate' => '1995-07-10T20:59:59',
            'validityStartDate' => '2018-06-03T00:00:00',
            'footnote' => {
              'footnoteId' => '08',
              'footnoteType' => {
                'footnoteTypeId' => '06',
              },
            },
            'metainfo' => {
              'opType' => 'C',
              'transactionDate' => '2017-08-27T19:23:57',
            },
          },
          'metainfo' => {
            'origin' => 'T',
            'opType' => 'U',
            'transactionDate' => '2016-07-27T09:20:15',
          },
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: Time.parse('2018-06-03T00:00:00.000Z'),
        validity_end_date: Time.parse('1995-07-10T20:59:59.000Z'),
        operation: 'C',
        operation_date: Date.parse('2017-08-27'),
        meursing_table_plan_id: '2',
        meursing_heading_number: '6',
        row_column_code: 1,
        footnote_type: '06',
        footnote_id: '08',
      }
    end

    let(:expected_entity_class) { 'FootnoteAssociationMeursingHeading' }
    let(:expected_mapping_root) { 'MeursingTablePlan' }
  end
end
