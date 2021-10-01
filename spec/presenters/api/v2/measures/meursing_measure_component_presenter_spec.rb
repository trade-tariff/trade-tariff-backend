RSpec.describe Api::V2::Measures::MeursingMeasureComponentPresenter do
  subject(:presenter) { described_class.new(measure_component) }

  let(:measure_component) do
    create(
      :measure_component,
      :agricultural_meursing,
      :with_duty_expression,
      duty_amount: 100,
      measurement_unit_code: 'DTN',
      monetary_unit_code: 'EUR',
      measure_sid: create(:meursing_measure).measure_sid,
    )
  end

  before do
    allow(DutyExpressionFormatter).to receive(:format).and_call_original
  end

  describe '#formatted_duty_expression' do
    it { expect(presenter.formatted_duty_expression).to eq('<strong>+ <span>100.00</span> EUR</strong>') }

    it 'calls the DutyExpressionFormatter with the correct options' do
      presenter.formatted_duty_expression

      expect(DutyExpressionFormatter).to have_received(:format).with(
        duty_expression_id: '04', # Forces meursing component to always be a standard duty expression in a sequence
        duty_expression_abbreviation: '+', # Fixes incorrect abbreviation that would have been inherited from the root measure
        resolved_meursing: true, # Marks the component to be formatted as a resolved component
        formatted: true, # Adds html tags to the component
        currency: 'GBP',
        duty_amount: 100.0,
        duty_expression_description: measure_component.duty_expression_description,
        measurement_unit: nil,
        measurement_unit_qualifier: nil,
        monetary_unit: 'EUR',
        monetary_unit_abbreviation: nil,
      )
    end
  end
end
