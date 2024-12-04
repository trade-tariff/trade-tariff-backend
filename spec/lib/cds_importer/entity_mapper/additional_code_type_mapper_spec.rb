RSpec.describe CdsImporter::EntityMapper::AdditionalCodeTypeMapper do
  let(:xml_node) do
    {
      'applicationCode' => '1',
      'additionalCodeTypeId' => '3',
      'validityStartDate' => '1970-01-01T00:00:00',
      'meursingTablePlan' => { 'meursingTablePlanId' => '01' },
      'metainfo' => {
        'origin' => 'T',
        'opType' => operation,
        'transactionDate' => '2016-07-27T09:18:51',
      },
      'additionalCodeTypeMeasureType' => {
        'validityStartDate' => '1999-09-01T00:00:00',
        'measureType' => {
          'measureTypeId' => '468',
        },
        'metainfo' => {
          'opType' => operation,
          'origin' => 'N',
          'transactionDate' => '2016-07-22T20:03:35',
        },
      },
      'additionalCodeTypeDescription' => {
        'description' => 'Prohibition/Restriction/Surveillance',
        'language' => {
          'languageId' => 'EN',
        },
        'metainfo' => {
          'origin' => 'T',
          'opType' => operation,
          'transactionDate' => '2016-07-27T09:18:51',
        },
      },
    }
  end

  let(:operation) { 'U' }

  it_behaves_like 'an entity mapper', 'AdditionalCodeType', 'AdditionalCodeType' do
    let(:expected_values) do
      {
        validity_start_date: Time.zone.parse('1970-01-01T00:00:00.000Z'),
        validity_end_date: nil,
        national: false,
        operation: 'U',
        operation_date: Date.parse('2016-07-27'),
        application_code: '1',
        additional_code_type_id: '3',
        meursing_table_plan_id: '01',
      }
    end
  end

  describe '#import' do
    subject(:entity_mapper) { CdsImporter::EntityMapper.new('AdditionalCodeType', xml_node) }

    context 'when the additional code type is being updated' do
      let(:operation) { 'U' }

      it_behaves_like 'an entity mapper update operation', AdditionalCodeType
      it_behaves_like 'an entity mapper update operation', AdditionalCodeTypeDescription
      it_behaves_like 'an entity mapper update operation', AdditionalCodeTypeMeasureType
    end

    context 'when the additional code type is being created' do
      let(:operation) { 'C' }

      it_behaves_like 'an entity mapper create operation', AdditionalCodeType
      it_behaves_like 'an entity mapper create operation', AdditionalCodeTypeDescription
      it_behaves_like 'an entity mapper create operation', AdditionalCodeTypeMeasureType
    end

    context 'when the additional code type is being deleted' do
      before do
        create(:additional_code_type, additional_code_type_id: '3')
        create(:additional_code_type_measure_type, measure_type_id: '468', additional_code_type_id: '3')
        create(:additional_code_type_description, additional_code_type_id: '3', language_id: 'EN')
      end

      let(:operation) { 'D' }

      it_behaves_like 'an entity mapper destroy operation', AdditionalCodeType
      it_behaves_like 'an entity mapper destroy operation', AdditionalCodeTypeDescription
      it_behaves_like 'an entity mapper destroy operation', AdditionalCodeTypeMeasureType
    end
  end
end
