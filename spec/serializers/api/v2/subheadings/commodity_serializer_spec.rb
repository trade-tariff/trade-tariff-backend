RSpec.describe Api::V2::Subheadings::CommoditySerializer do
  subject(:serializer) { described_class.new(serializable).serializable_hash.as_json }

  let(:serializable) do
    Hashie::TariffMash.new(
      'id' => 5,
      'goods_nomenclature_sid' => 5,
      'goods_nomenclature_item_id' => '0101290000',
      'validity_start_date' => '2019-01-25T00:00:00.000Z',
      'validity_end_date' => nil,
      'goods_nomenclature_indents' => [{ 'goods_nomenclature_indent_sid' => 10, 'validity_start_date' => '2020-01-26T00:00:00.000Z', 'validity_end_date' => nil, 'number_indents' => 2, 'productline_suffix' => '80' }],
      'goods_nomenclature_descriptions' => [{ 'goods_nomenclature_description_period_sid' => 11, 'validity_start_date' => '2020-01-26T00:00:00.000Z', 'validity_end_date' => nil, 'description' => 'voMrkLOGSd0R1', 'formatted_description' => 'voMrkLOGSd0R1', 'description_plain' => 'voMrkLOGSd0R1' }],
      'overview_measures' => [
        {
          'measure_sid' => 1,
          'effective_start_date' => '2019-01-26T00:00:00.000Z',
          'effective_end_date' => '2032-01-26T00:00:00.000Z',
          'goods_nomenclature_sid' => 5,
          'vat' => true,
          'duty_expression_id' => '1-duty_expression',
          'duty_expression' => { 'id' => '1-duty_expression', 'base' => '', 'formatted_base' => '' },
          'measure_type_id' => nil,
          'measure_type' => { 'measure_type_id' => '305', 'description' => 'lNyLZN3oP2E0' },
        },
        {
          'measure_sid' => 2,
          'effective_start_date' => '2019-01-26T00:00:00.000Z',
          'effective_end_date' => '2032-01-26T00:00:00.000Z',
          'goods_nomenclature_sid' => 5,
          'vat' => false,
          'duty_expression_id' => '2-duty_expression',
          'duty_expression' => { 'id' => '2-duty_expression', 'base' => '', 'formatted_base' => '' },
          'measure_type_id' => nil,
          'measure_type' => { 'measure_type_id' => '105', 'description' => '38tn2006tA' },
        },
        {
          'measure_sid' => 3,
          'effective_start_date' => '2019-01-26T00:00:00.000Z',
          'effective_end_date' => '2032-01-26T00:00:00.000Z',
          'goods_nomenclature_sid' => 5,
          'vat' => false,
          'duty_expression_id' => '3-duty_expression',
          'duty_expression' => { 'id' => '3-duty_expression', 'base' => '', 'formatted_base' => '' },
          'measure_type_id' => nil,
          'measure_type' => { 'measure_type_id' => '109', 'description' => 'KKAwtWRvz6Qbc' },
        },
      ],
      'parent_sid' => 1,
      'leaf' => true,
      'number_indents' => 2,
      'producline_suffix' => '80',
      'description' => 'voMrkLOGSd0R1',
      'formatted_description' => 'voMrkLOGSd0R1',
      'description_plain' => 'voMrkLOGSd0R1',
      'overview_measure_ids' => [1, 2, 3],
    )
  end

  let(:expected_pattern) do
    {
      'data' => {
        'id' => '5',
        'type' => 'commodity',
        'attributes' => {
          'formatted_description' => 'voMrkLOGSd0R1',
          'description_plain' => 'voMrkLOGSd0R1',
          'number_indents' => 2,
          'goods_nomenclature_item_id' => '0101290000',
          'producline_suffix' => '80',
          'goods_nomenclature_sid' => 5,
          'parent_sid' => 1,
          'leaf' => true,
          'productline_suffix' => '80',
        },
        'relationships' => {
          'overview_measures' => {
            'data' => [
              { 'id' => '1', 'type' => 'measure' },
              { 'id' => '2', 'type' => 'measure' },
              { 'id' => '3', 'type' => 'measure' },
            ],
          },
        },
      },
    }
  end

  describe '#serializable_hash' do
    it { is_expected.to include_json(expected_pattern) }
  end
end
