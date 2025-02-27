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

  describe '#import' do
    subject(:entity_mapper) { CdsImporter::EntityMapper.new('Footnote', xml_node) }

    let(:xml_node) do
      {
        'metainfo' => {
          'origin' => 'T',
          'opType' => operation,
          'transactionDate' => '2016-07-27T09:18:57',
        },
        'footnoteId' => '133',
        'footnoteType' => { 'footnoteTypeId' => 'TM' },
        'footnoteDescriptionPeriod' => {
          'sid' => '1355',
          'footnoteDescription' => {
            'description' => 'The rate of duty is applicable to the net free-at-Community',
            'language' => { 'languageId' => 'EN' },
            'metainfo' => {
              'origin' => 'T',
              'opType' => operation,
              'transactionDate' => '2016-07-27T09:18:57',
            },
          },
          'metainfo' => {
            'origin' => 'T',
            'opType' => operation,
            'transactionDate' => '2016-07-27T09:18:57',
          },
        },
      }
    end

    context 'when the footnote is being updated' do
      let(:operation) { 'U' }

      it_behaves_like 'an entity mapper update operation', Footnote
      it_behaves_like 'an entity mapper update operation', FootnoteDescriptionPeriod
      it_behaves_like 'an entity mapper update operation', FootnoteDescription
    end

    context 'when the footnote is being created' do
      let(:operation) { 'C' }

      it_behaves_like 'an entity mapper create operation', Footnote
      it_behaves_like 'an entity mapper create operation', FootnoteDescriptionPeriod
      it_behaves_like 'an entity mapper create operation', FootnoteDescription
    end

    context 'when the footnote is being deleted' do
      before do
        create(:footnote, footnote_id: '133', footnote_type_id: 'TM')
        create(:footnote_description_period, footnote_description_period_sid: '1355', footnote_type_id: 'TM', footnote_id: '133')
        create(:footnote_description, footnote_description_period_sid: '1355', footnote_type_id: 'TM', footnote_id: '133')
      end

      let(:operation) { 'D' }

      it_behaves_like 'an entity mapper destroy operation', Footnote
      it_behaves_like 'an entity mapper destroy operation', FootnoteDescription
      it_behaves_like 'an entity mapper destroy operation', FootnoteDescriptionPeriod
    end
  end
end
