RSpec.describe CdsImporter::EntityMapper::AdditionalCodeTypeMapper do
  let(:xml_node) do
    {
      'applicationCode' => '1',
      'additionalCodeTypeId' => additional_code_type_id,
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
          'measureTypeId' => measure_type_id,
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
          'languageId' => language_id,
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
  let(:additional_code_type_id) { '3' }
  let(:language_id) { 'EN' }
  let(:measure_type_id) { '468' }

  it_behaves_like 'an entity mapper', 'AdditionalCodeType', 'AdditionalCodeType' do
    let(:expected_values) do
      {
        validity_start_date: Time.zone.parse('1970-01-01T00:00:00.000Z'),
        validity_end_date: nil,
        national: false,
        operation: 'U',
        operation_date: Date.parse('2016-07-27'),
        application_code: '1',
        additional_code_type_id:,
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
        create(
          :additional_code_type,
          :with_description,
          :with_measure_type,
          additional_code_type_id:,
        )
      end

      let(:operation) { 'D' }

      it_behaves_like 'an entity mapper destroy operation', AdditionalCodeType
      it_behaves_like 'an entity mapper destroy operation', AdditionalCodeTypeDescription
      it_behaves_like 'an entity mapper destroy operation', AdditionalCodeTypeMeasureType
    end

    context 'when there are missing secondary entities to be soft deleted' do
      before do
        # Creates entities that will be missing from the xml node
        create(
          :additional_code_type,
          :with_description,
          :with_measure_type,
          additional_code_type_id:,
          language_id: 'NO',
        )

        # Control for a non-deleted entities
        create(:additional_code_type_measure_type, measure_type_id:, additional_code_type_id:)
        create(:additional_code_type_description, additional_code_type_id:, language_id:)
      end

      it_behaves_like('an entity mapper missing destroy operation', AdditionalCodeTypeDescription, additional_code_type_id:)
      it_behaves_like('an entity mapper missing destroy operation', AdditionalCodeTypeMeasureType, additional_code_type_id:)
    end
  end
end
