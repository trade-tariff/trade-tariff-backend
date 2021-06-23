require 'rails_helper'

RSpec.describe Api::V2::Measures::MeasureSerializer do
  subject(:serializer) { described_class.new(serializable).serializable_hash.as_json }

  let(:serializable) { Api::V2::Measures::MeasurePresenter.new(measure, measure.goods_nomenclature) }
  let(:measure) { create(:measure) }

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
        },
        'relationships' => {
          'duty_expression' => {
            'data' => {
              'id' => "#{measure.id}-duty_expression",
              'type' => 'duty_expression',
            },
          },
          'measure_type' => {
            'data' => {
              'id' => measure.measure_type_id,
              'type' => 'measure_type',
            },
          },
          'legal_acts' => { 'data' => [] },
          'measure_conditions' => { 'data' => [] },
          'measure_components' => { 'data' => [] },
          'national_measurement_units' => { 'data' => [] },
          'geographical_area' => {
            'data' => {
              'id' => measure.geographical_area_id,
              'type' => 'geographical_area',
            },
          },
          'excluded_countries' => { 'data' => [] },
          'footnotes' => { 'data' => [] },
          'order_number' => { 'data' => nil },
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
