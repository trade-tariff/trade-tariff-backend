RSpec.describe CdsImporter::EntityMapper::FootnoteDescriptionPeriodMapper do
  let(:xml_node) do
    {
      'footnoteId' => '123',
      'footnoteType' => {
        'footnoteTypeId' => 'TM',
      },
      'footnoteDescriptionPeriod' => {
        'sid' => '1355',
        'validityStartDate' => '1972-01-01T00:00:00',
        'validityEndDate' => '1973-01-01T00:00:00',
        'metainfo' => {
          'opType' => 'C',
          'origin' => 'T',
          'transactionDate' => '2016-07-27T09:18:57',
        },
      },
    }
  end

  it_behaves_like 'an entity mapper', 'FootnoteDescriptionPeriod', 'Footnote' do
    let(:expected_values) do
      {
        validity_start_date: '1972-01-01T00:00:00.000Z',
        validity_end_date: '1973-01-01T00:00:00.000Z',
        national: false,
        operation: 'C',
        operation_date: Date.parse('2016-07-27'),
        footnote_description_period_sid: 1355,
        footnote_type_id: 'TM',
        footnote_id: '123',
      }
    end
  end
end
