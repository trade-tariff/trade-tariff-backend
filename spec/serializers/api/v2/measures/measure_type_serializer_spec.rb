RSpec.describe Api::V2::Measures::MeasureTypeSerializer do
  let(:measure_type) { create(:measure_type, :with_measure_type_series_description) }

  let(:expected_pattern) do
    {
      data: {
        id: measure_type.id,
        type: :measure_type,
        attributes: {
          id: measure_type.id,
          description: measure_type.description,
          measure_component_applicable_code: measure_type.measure_component_applicable_code,
          measure_type_series_description: measure_type.measure_type_series_description.description,
          measure_type_series_id: measure_type.measure_type_series_id,
          order_number_capture_code: measure_type.order_number_capture_code,
          trade_movement_code: measure_type.trade_movement_code,
          validity_end_date: measure_type.validity_end_date,
          validity_start_date: measure_type.validity_start_date,
        },
      },
    }
  end

  describe '#serializable_hash' do
    it 'serializes the correct attributes' do
      actual = described_class.new(measure_type).serializable_hash

      expect(actual).to include(expected_pattern)
    end
  end
end
