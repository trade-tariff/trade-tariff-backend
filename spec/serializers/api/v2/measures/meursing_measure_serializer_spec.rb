RSpec.describe Api::V2::Measures::MeursingMeasureSerializer do
  subject(:serializer) { described_class.new(serializable).serializable_hash.as_json }

  let(:serializable) { Api::V2::Measures::MeursingMeasurePresenter.new(meursing_measure) }
  let(:meursing_measure) { create(:measure, :with_meursing_measure) }

  let(:expected_pattern) do
    {
      'data' => {
        'id' => meursing_measure.measure_sid.to_s,
        'type' => :measure,
        'attributes' => {
          'reduction_indicator' => meursing_measure.reduction_indicator,
          'formatted_duty_expression' => '',
        },
        'relationships' => {
          'geographical_area' => {
            'data' => {
              'id' => meursing_measure.geographical_area_id,
              'type' => 'geographical_area',
            },
          },
          'measure_type' => {
            'data' => {
              'id' => meursing_measure.measure_type_id,
              'type' => 'measure_type',
            },
          },
          'measure_components' => { 'data' => [] },
          'additional_code' => { 'data' => nil },
        },
      },
    }.as_json
  end

  describe '#serializable_hash' do
    it { is_expected.to include_json(expected_pattern) }
  end
end
