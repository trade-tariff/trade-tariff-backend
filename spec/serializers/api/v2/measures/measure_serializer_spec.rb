RSpec.describe Api::V2::Measures::MeasureSerializer do
  subject(:serializer) { described_class.new(serializable).serializable_hash.as_json }

  let(:serializable) { Api::V2::Measures::MeasurePresenter.new(measure, measure.goods_nomenclature) }
  let(:measure) { create(:measure, :with_goods_nomenclature, reduction_indicator: 1) }

  let(:expected_pattern) do
    {
      'data' => {
        'id' => measure.measure_sid.to_s,
        'type' => 'measure',
        'attributes' => {
          'id' => measure.measure_sid,
          'origin' => 'eu',
          'effective_start_date' => nil,
          'effective_end_date' => nil,
          'import' => true,
          'excise' => false,
          'vat' => false,
          'reduction_indicator' => 1,
        },
        'relationships' => {
          'duty_expression' => {},
          'measure_type' => {},
          'legal_acts' => {},
          'measure_conditions' => {},
          'measure_components' => {},
          'national_measurement_units' => {},
          'geographical_area' => {},
          'excluded_countries' => {},
          'footnotes' => {},
          'order_number' => {},
        },
        'meta' => {
          'duty_calculator' => {
            'source' => 'uk',
          },
        },
      },
    }.as_json
  end

  describe '#serializable_hash' do
    it { is_expected.to include_json(expected_pattern) }
  end
end
