RSpec.describe CdsImporter::EntityMapper::AdditionalCodeTypeMapper do
  it_behaves_like 'an entity mapper', 'AdditionalCodeType', 'AdditionalCodeType' do
    let(:xml_node) do
      {
        'applicationCode' => '1',
        'additionalCodeTypeId' => '3',
        'validityStartDate' => '1970-01-01T00:00:00',
        'meursingTablePlan' => { 'meursingTablePlanId' => '01' },
        'metainfo' => {
          'origin' => 'T',
          'opType' => 'U',
          'transactionDate' => '2016-07-27T09:18:51',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: Time.zone.parse('1970-01-01T00:00:00.000Z'),
        validity_end_date: nil,
        national: false,
        operation: 'U',
        operation_date: Date.parse('2016-07-27'),
        application_code: '1',
        additional_code_type_id: '3',
        meursing_table_plan_id: '01',
      }
    end
  end
end
