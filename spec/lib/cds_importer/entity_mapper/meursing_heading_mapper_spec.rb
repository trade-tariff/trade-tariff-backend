RSpec.describe CdsImporter::EntityMapper::MeursingHeadingMapper do
  it_behaves_like 'an entity mapper', 'MeursingHeading', 'MeursingTablePlan' do
    let(:xml_node) do
      {
        'meursingTablePlanId' => '03',
        'meursingHeading' => {
          'sid' => '3084',
          'validityEndDate' => '1996-06-14T23:59:59',
          'validityStartDate' => '1991-06-01T00:00:00',
          'meursingHeadingNumber' => '20',
          'rowColumnCode' => '1',
          'metainfo' => {
            'opType' => 'C',
            'transactionDate' => '2016-07-27T09:20:15',
          },
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: Time.zone.parse('1991-06-01T00:00:00.000Z'),
        validity_end_date: Time.zone.parse('1996-06-14T23:59:59.000Z'),
        operation: 'C',
        operation_date: Date.parse('2016-07-27'),
        meursing_table_plan_id: '03',
        meursing_heading_number: '20',
        row_column_code: 1,
      }
    end
  end
end
