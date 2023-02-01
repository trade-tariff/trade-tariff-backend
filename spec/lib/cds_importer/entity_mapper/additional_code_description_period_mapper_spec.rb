RSpec.describe CdsImporter::EntityMapper::AdditionalCodeDescriptionPeriodMapper do
  let(:xml_node) do
    {
      'sid' => '3084',
      'additionalCodeCode' => '169',
      'additionalCodeType' => {
        'additionalCodeTypeId' => '8',
      },
      'additionalCodeDescriptionPeriod' => {
        'sid' => '536',
        'validityStartDate' => '1991-06-01T00:00:00',
        'validityEndDate' => '1992-06-01T00:00:00',
        'metainfo' => {
          'origin' => 'T',
          'opType' => 'C',
          'transactionDate' => '2016-08-27T09:20:14',
        },
      },
    }
  end

  it_behaves_like 'an entity mapper', 'AdditionalCodeDescriptionPeriod', 'AdditionalCode' do
    let(:expected_values) do
      {
        validity_start_date: Time.zone.parse('1991-06-01T00:00:00.000Z'),
        validity_end_date: Time.zone.parse('1992-06-01T00:00:00.000Z'),
        operation: 'C',
        operation_date: Date.parse('2016-08-27'),
        additional_code_description_period_sid: 536,
        additional_code_sid: 3084,
        additional_code_type_id: '8',
        additional_code: '169',
      }
    end
  end

  describe '#import' do
    subject(:entity_mapper) { CdsImporter::EntityMapper.new('AdditionalCode', xml_node) }

    context 'when there are missing secondary entities to be soft deleted' do
      before do
        # Creates entities that will be missing from the xml node
        create(:additional_code_description, additional_code_sid: '3084', additional_code_description_period_sid: '536')
      end

      it_behaves_like 'an entity mapper missing destroy operation', AdditionalCodeDescription, additional_code_description_period_sid: '536', additional_code_sid: '3084'
    end
  end
end
