RSpec.describe MeursingMeasureComponentResolverService do
  subject(:service) do
    described_class.new(
      root_measure,
      [meursing_agricultural_measure, more_specific_agricultural_measure],
    )
  end

  describe '#call' do
    let(:root_measure) do
      measure = create(
        :measure,
        :third_country,
        geographical_area_id: 'RO',
      )

      # Ad valorem measure component
      create(
        :measure_component,
        :with_duty_expression,
        measure_sid: measure.measure_sid,
        duty_expression_id: '01',
      )
      # Placeholder meursing measure component - agricultural component
      create(
        :measure_component,
        :with_duty_expression,
        measure_sid: measure.measure_sid,
        duty_expression_id: '12',
      )

      measure.reload
    end

    let(:meursing_agricultural_measure) { create(:measure, :agricultural, geographical_area_id: '1011') }
    let(:more_specific_agricultural_measure) { create(:measure, :agricultural, geographical_area_id: 'RO') }

    let(:meursing_agricultural_measure_component) do
      create(
        :measure_component,
        duty_amount: 0.0,
        monetary_unit_code: 'EUR',
        measurement_unit_code: 'DTN',
        measure_sid: meursing_agricultural_measure.measure_sid,
      )
    end

    let(:more_specific_meursing_agricultural_measure_component) do
      create(
        :measure_component,
        duty_amount: 0.0,
        monetary_unit_code: 'EUR',
        measurement_unit_code: 'DTN',
        measure_sid: more_specific_agricultural_measure.measure_sid,
      )
    end

    it 'picks the most specific match' do
      expected_measure_components = [
        root_measure.measure_components.first,
        more_specific_meursing_agricultural_measure_component,
      ].map(&:pk)

      actual_measure_components = service.call.map(&:pk)

      expect(actual_measure_components).to eq(expected_measure_components)
    end
  end
end
