RSpec.describe CdsImporter::EntityMapper::FootnoteDescriptionMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'footnoteId' => '133',
        'footnoteType' => {
          'footnoteTypeId' => 'TM',
        },
        'footnoteDescriptionPeriod' => {
          'sid' => '1355',
          'footnoteDescription' => {
            'description' => 'The rate of duty is applicable to the net free-at-Community',
            'language' => {
              'languageId' => 'EN',
            },
            'metainfo' => {
              'origin' => 'T',
              'opType' => 'C',
              'transactionDate' => '2016-07-27T09:18:57',
            },
          },
        },
      }
    end

    let(:expected_values) do
      {
        national: false,
        operation: 'C',
        operation_date: Date.parse('2016-07-27'),
        footnote_description_period_sid: 1355,
        footnote_type_id: 'TM',
        footnote_id: '133',
        language_id: 'EN',
        description: 'The rate of duty is applicable to the net free-at-Community',
      }
    end

    let(:expected_entity_class) { 'FootnoteDescription' }
    let(:expected_mapping_root) { 'Footnote' }
  end
end
