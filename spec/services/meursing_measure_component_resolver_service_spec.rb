RSpec.describe MeursingMeasureComponentResolverService do
  subject(:service) do
    described_class.new(
      root_measure.reload,
      [meursing_agricultural_measure],
    )
  end

  describe '#call' do
    before do
      root_measure_components
      meursing_agricultural_measure_component
    end

    let(:root_measure) { create(:measure, :third_country) }

    let(:meursing_sugar_measure) { create(:measure, :sugar) }
    let(:meursing_agricultural_measure) { create(:measure, :agricultural) }

    let(:meursing_agricultural_measure_component) do
      create(
        :measure_component,
        duty_amount: 0.0,
        monetary_unit_code: 'EUR',
        measurement_unit_code: 'DTN',
        measure_sid: meursing_agricultural_measure.measure_sid,
      )

      meursing_agricultural_measure.reload
    end

    let(:root_measure_components) do
      [
        create(
          :measure_component,
          :with_duty_expression,
          measure_sid: root_measure.measure_sid,
          duty_expression_id: '01',
        ), # Ad valorem measure component
        create(
          :measure_component,
          :with_duty_expression,
          measure_sid: root_measure.measure_sid,
          duty_expression_id: '12',
        ), # Placeholder meursing measure component - agricultural component
      ]
    end

    it 'returns a correct set of resolved placeholder measure components' do
      expected_measure_components = [
        root_measure_components[0],              # Ad valorem
        meursing_agricultural_measure_component, # Agricultural
      ].map(&:pk)

      actual_measure_components = service.call.map(&:pk)

      expect(actual_measure_components).to eq(expected_measure_components)
    end
  end
end
