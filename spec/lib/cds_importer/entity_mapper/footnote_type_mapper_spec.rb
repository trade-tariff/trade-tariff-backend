RSpec.describe CdsImporter::EntityMapper::FootnoteTypeMapper do
  it_behaves_like 'an entity mapper', 'FootnoteType', 'FootnoteType' do
    let(:xml_node) do
      {
        'footnoteTypeId' => 'TN',
        'applicationCode' => '2',
        'validityStartDate' => '1970-01-01T00:00:00',
        'validityEndDate' => '1972-01-01T00:00:00',
        'metainfo' => {
          'opType' => 'C',
          'origin' => 'T',
          'transactionDate' => '2016-07-27T09:18:51',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: Time.zone.parse('1970-01-01T00:00:00'),
        validity_end_date: Time.zone.parse('1972-01-01T00:00:00'),
        national: false,
        operation: 'C',
        operation_date: Date.parse('2016-07-27'),
        footnote_type_id: 'TN',
        application_code: 2,
      }
    end
  end
end
