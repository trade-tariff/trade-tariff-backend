RSpec.describe CdsImporter::EntityMapper::FootnoteMapper do
  it_behaves_like 'an entity mapper', 'Footnote', 'Footnote' do
    let(:xml_node) do
      {
        'footnoteId' => '133',
        'validityStartDate' => '1972-01-01T00:00:00',
        'validityEndDate' => '1973-01-01T00:00:00',
        'footnoteType' => {
          'footnoteTypeId' => 'TM',
        },
        'metainfo' => {
          'opType' => 'U',
          'origin' => 'T',
          'transactionDate' => '2016-07-27T09:18:57',
        },
      }
    end

    let(:expected_values) do
      {
        validity_start_date: '1972-01-01T00:00:00.000Z',
        validity_end_date: '1973-01-01T00:00:00.000Z',
        national: false,
        operation: 'U',
        operation_date: Date.parse('2016-07-27'),
        footnote_id: '133',
        footnote_type_id: 'TM',
      }
    end
  end
end
