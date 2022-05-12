RSpec.describe CdsImporter::EntityMapper::FootnoteAssociationMeasureMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'sid' => '3084',
        'validityEndDate' => '1996-06-14T23:59:59',
        'validityStartDate' => '1991-06-01T00:00:00',
        'footnoteAssociationMeasure' => {
          'footnote' => {
            'footnoteId' => '08',
            'footnoteType' => {
              'footnoteTypeId' => '06',
            },
          },
          'metainfo' => {
            'opType' => 'C',
            'origin' => 'N',
            'transactionDate' => '2017-08-27T19:23:57',
          },
        },
        'metainfo' => {
          'origin' => 'T',
          'opType' => 'U',
          'transactionDate' => '2016-07-27T09:20:15',
        },
      }
    end

    let(:expected_values) do
      {
        national: true,
        operation: 'C',
        operation_date: Date.parse('2017-08-27'),
        measure_sid: 3084,
        footnote_type_id: '06',
        footnote_id: '08',
      }
    end

    let(:expected_entity_class) { 'FootnoteAssociationMeasure' }
    let(:expected_mapping_root) { 'Measure' }
  end
end
