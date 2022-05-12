RSpec.describe CdsImporter::EntityMapper::RegulationReplacementMapper do
  it_behaves_like 'an entity mapper' do
    let(:xml_node) do
      {
        'replacedRegulationRole' => '1',
        'replacingRegulationRole' => '1',
        'replacedRegulationId' => 'C9600110',
        'replacingRegulationId' => 'R9608580',
        'geographicalArea' => {
          'geographicalAreaId' => '1011',
        },
        'measureType' => {
          'measureTypeId' => '2',
        },
        'chapterHeading' => '123',
        'metainfo' => {
          'opType' => 'U',
          'transactionDate' => '2017-06-29T20:04:37',
        },
      }
    end

    let(:expected_values) do
      {
        operation: 'U',
        operation_date: Date.parse('2017-06-29'),
        geographical_area_id: '1011',
        chapter_heading: '123',
        replacing_regulation_role: 1,
        replacing_regulation_id: 'R9608580',
        replaced_regulation_role: 1,
        replaced_regulation_id: 'C9600110',
        measure_type_id: '2',
      }
    end

    let(:expected_entity_class) { 'RegulationReplacement' }
    let(:expected_mapping_root) { 'RegulationReplacement' }
  end
end
