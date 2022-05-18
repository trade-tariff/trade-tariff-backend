RSpec.describe CdsImporter::EntityMapper::MeursingTableCellComponentMapper do
  it_behaves_like 'an entity mapper', 'MeursingTableCellComponent', 'MeursingAdditionalCode' do
    let(:xml_node) do
      {
        'sid' => '359',
        'additionalCodeCode' => '475',
        'validityStartDate' => '1988-01-01T00:00:00',
        'meursingCellComponent' => {
          'metainfo' => {
            'opType' => 'C',
            'origin' => 'T',
            'transactionDate' => '2016-06-22T10:20:13',
          },
          'validityStartDate' => '2016-08-22T11:30:13',
          'validityEndtDate' => '2026-08-22T11:30:13',
          'meursingSubheading' => {
            'hjid' => '508826',
            'subheadingSequenceNumber' => '150',
            'meursingHeading' => {
              'meursingHeadingNumber' => '10',
              'rowColumnCode' => '1',
              'meursingTablePlan' => {
                'meursingTablePlanId' => '01',
              },
            },
          },
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: '2016-08-22T11:30:13.000Z',
        validity_end_date: nil,
        operation: 'C',
        operation_date: Date.parse('2016-06-22'),
        meursing_additional_code_sid: 359,
        additional_code: '475',
        meursing_table_plan_id: '01',
        heading_number: 10,
        row_column_code: 1,
        subheading_sequence_number: 150,
      }
    end
  end
end
