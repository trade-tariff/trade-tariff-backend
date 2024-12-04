RSpec.describe CdsImporter::EntityMapper::AdditionalCodeMapper do
  let(:xml_node) do
    {
      'sid' => '3084',
      'additionalCodeCode' => '169',
      'validityEndDate' => '1996-06-14T23:59:59',
      'validityStartDate' => '1991-06-01T00:00:00',
      'additionalCodeType' => {
        'additionalCodeTypeId' => '8',
      },
      'metainfo' => {
        'origin' => 'T',
        'opType' => operation,
        'transactionDate' => '2016-07-27T09:20:15',
      },
      'footnoteAssociationAdditionalCode' => {
        'footnote' => {
          'footnoteId' => '08',
          'footnoteType' => {
            'footnoteTypeId' => '06',
          },
        },
        'metainfo' => {
          'opType' => operation,
          'transactionDate' => '2017-08-27T19:23:57',
        },
      },
      'additionalCodeDescriptionPeriod' => {
        'sid' => '536',
        'additionalCodeDescription' => {
          'description' => 'Other.',
          'language' => {
            'languageId' => 'EN',
          },
          'metainfo' => {
            'origin' => 'T',
            'opType' => operation,
            'transactionDate' => '2016-07-27T09:20:14',
          },
        },
        'metainfo' => {
          'origin' => 'T',
          'opType' => operation,
          'transactionDate' => '2016-07-27T09:20:14',
        },
      },
    }
  end

  let(:operation) { 'C' }

  it_behaves_like 'an entity mapper', 'AdditionalCode', 'AdditionalCode' do
    let(:expected_values) do
      {
        validity_start_date: Time.zone.parse('1991-06-01T00:00:00.000Z'),
        validity_end_date: Time.zone.parse('1996-06-14T23:59:59.000Z'),
        national: false,
        operation: 'C',
        operation_date: Date.parse('2016-07-27'),
        additional_code_sid: 3084,
        additional_code_type_id: '8',
        additional_code: '169',
      }
    end
  end

  describe '#import' do
    subject(:entity_mapper) { CdsImporter::EntityMapper.new('AdditionalCode', xml_node) }

    context 'when the additional code is being updated' do
      let(:operation) { 'U' }

      it_behaves_like 'an entity mapper update operation', AdditionalCode
      it_behaves_like 'an entity mapper update operation', FootnoteAssociationAdditionalCode
      it_behaves_like 'an entity mapper update operation', AdditionalCodeDescriptionPeriod
      it_behaves_like 'an entity mapper update operation', AdditionalCodeDescription
    end

    context 'when the additional code is being created' do
      let(:operation) { 'C' }

      it_behaves_like 'an entity mapper create operation', AdditionalCode
      it_behaves_like 'an entity mapper create operation', FootnoteAssociationAdditionalCode
      it_behaves_like 'an entity mapper create operation', AdditionalCodeDescriptionPeriod
      it_behaves_like 'an entity mapper create operation', AdditionalCodeDescription
    end

    context 'when the additional code is being deleted' do
      before do
        # Creates entities that will soft deleted
        create(:additional_code, additional_code_sid: '3084')
        create(:footnote_association_additional_code, additional_code_sid: '3084', footnote_type_id: '06', footnote_id: '08')
        create(:additional_code_description_period, additional_code_description_period_sid: '536', additional_code_sid: '3084', additional_code_type_id: '8')
        create(:additional_code_description, additional_code_description_period_sid: '536', additional_code_sid: '3084')
      end

      let(:operation) { 'D' }

      it_behaves_like 'an entity mapper destroy operation', AdditionalCode
      it_behaves_like 'an entity mapper destroy operation', FootnoteAssociationAdditionalCode
      it_behaves_like 'an entity mapper destroy operation', AdditionalCodeDescriptionPeriod
    end
  end
end
