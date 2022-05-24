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

    before do
      create(
        :footnote,
        :with_additional_code_association,
        :with_gono_association,
        :with_measure_association,
        :with_meursing_heading_association,
        footnote_id: '133',
        footnote_type_id: 'TM',
      )
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
      let(:operation) { 'D' }

      it_behaves_like 'an entity mapper destroy operation', Footnote
      it_behaves_like 'an entity mapper destroy operation', FootnoteAssociationAdditionalCode
      it_behaves_like 'an entity mapper destroy operation', FootnoteAssociationGoodsNomenclature
      it_behaves_like 'an entity mapper destroy operation', FootnoteAssociationMeasure
      it_behaves_like 'an entity mapper destroy operation', FootnoteAssociationMeursingHeading
      it_behaves_like 'an entity mapper destroy operation', FootnoteDescription
      it_behaves_like 'an entity mapper destroy operation', FootnoteDescriptionPeriod
    end

    context 'when there are multiple footnote description periods and some are missing' do
      before do
        create( # Control for a non-deleted period
          :footnote_description_period,
          footnote_description_period_sid: '96004',
          footnote_type_id: 'TM',
          footnote_id: '133',
        )
      end

      let(:xml_node) do
        {
          'metainfo' => { 'opType' => 'U', 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2021-07-22T18:02:08' },
          'footnoteId' => '133',
          'validityStartDate' => '2010-02-01T00:00:00',
          'footnoteDescriptionPeriod' => [
            {
              'metainfo' => { 'opType' => 'U', 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2018-12-18T12:55:56' },
              'sid' => '96004',
              'validityStartDate' => '2010-02-01T00:00:00',
            },
            {
              'metainfo' => { 'opType' => 'U', 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2018-12-18T12:55:56' },
              'sid' => '96630',
              'validityStartDate' => '2015-01-01T00:00:00',
            },
            {
              'metainfo' => { 'opType' => 'C', 'origin' => 'T', 'status' => 'L', 'transactionDate' => '2021-07-22T18:02:08' },
              'sid' => '200577',
              'validityStartDate' => '2021-01-01T00:00:00',
            },
          ],
          'footnoteType' => { 'footnoteTypeId' => 'TM' },
        }
      end

      it_behaves_like 'an entity mapper missing destroy operation', FootnoteDescriptionPeriod, %i[footnote_description_period_sid footnote_type_id footnote_id], footnote_type_id: 'TM', footnote_id: '133'
    end
  end
end
