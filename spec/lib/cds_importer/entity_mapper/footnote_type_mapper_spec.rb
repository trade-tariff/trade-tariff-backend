RSpec.describe CdsImporter::EntityMapper::FootnoteTypeMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'footnoteTypeId' => 'TN',
        'applicationCode' => '2',
        'metainfo' => {
          'opType' => 'C',
          'origin' => 'T',
          'transactionDate' => '2016-07-27T09:18:51',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: nil,
        validity_end_date: nil,
        national: false,
        operation: 'C',
        operation_date: Date.parse('2016-07-27'),
        footnote_type_id: 'TN',
        application_code: 2,
      }
    end

    let(:expected_entity_class) { 'FootnoteType' }
    let(:expected_mapping_root) { 'FootnoteType' }
  end
end
