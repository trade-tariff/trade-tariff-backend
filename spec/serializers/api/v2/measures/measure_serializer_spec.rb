RSpec.describe Api::V2::Measures::MeasureSerializer do
  subject(:serializer) { described_class.new(serializable, options).serializable_hash.as_json }

  let(:serializable) { Api::V2::Measures::MeasurePresenter.new(measure.reload, measure.goods_nomenclature.reload) }
  let(:measure) { create(:measure, :with_meursing, :with_measure_components, reduction_indicator: 1) }
  let(:options) { {} }

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

    context 'when passing a meursing additional code' do
      let(:measure) { create(:measure, :third_country, reduction_indicator: 1) }

      let(:root_measure_components) do
        [
          create(
            :measure_component,
            :with_duty_expression,
            measure_sid: measure.measure_sid,
            duty_expression_id: '01',
          ), # Ad valorem measure component
          create(
            :measure_component,
            :with_duty_expression,
            measure_sid: measure.measure_sid,
            duty_expression_id: '12',
          ), # Placeholder meursing measure component - agricultural component
        ]
      end
      let(:options) { { params: { meursing_additional_code_id: '000' }, include: ['measure_components'] } }
      let(:finder_service) do
        instance_double(
          'MeursingMeasureFinderService',
          call: [build(:measure_component)],
        )
      end
      let(:resolver_service) do
        instance_double(
          'MeursingMeasureComponentResolverService',
          call: [],
        )
      end
      let(:meursing_agricultural_measure) { create(:measure, :agricultural) }
      let(:meursing_agricultural_measure_component) do
        create(
          :measure_component,
          duty_amount: 0.0,
          monetary_unit_code: 'EUR',
          measurement_unit_code: 'DTN',
          measure_sid: meursing_agricultural_measure.measure_sid,
        )
      end

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

      before do
        root_measure_components
        meursing_agricultural_measure_component
        allow(MeursingMeasureFinderService).to receive(:new).and_return(finder_service)
        allow(MeursingMeasureComponentResolverService).to receive(:new).and_return(resolver_service)
      end

      it 'calls the MeursingMeasureComponentResolverService' do
        serializer
        expect(MeursingMeasureComponentResolverService).to have_received(:new).once
      end

      it 'calls the MeursingMeasureFinderService' do
        serializer
        expect(MeursingMeasureFinderService).to have_received(:new).once
      end

      it { is_expected.to include_json(expected_pattern) }
    end
  end
end
