RSpec.describe DutyExpressionFormatter::OutputBuilder do
  subject(:output) { described_class.call(context) }

  let(:strategy) { instance_spy(Proc, call: %w[result]) }
  let(:context) { instance_double(DutyExpressionFormatter::Context, duty_expression_id: duty_expression_id) }

  context 'when the duty expression is unit only' do
    let(:duty_expression_id) { '99' }

    it 'dispatches to the unit-only strategy' do
      allow(DutyExpressionFormatter::Strategies::UnitOnly).to receive(:new).with(context).and_return(strategy)

      expect(output).to eq(%w[result])
      expect(DutyExpressionFormatter::Strategies::UnitOnly).to have_received(:new).with(context)
    end
  end

  context 'when the duty expression is description only' do
    let(:duty_expression_id) { '12' }

    it 'dispatches to the description-only strategy' do
      allow(DutyExpressionFormatter::Strategies::DescriptionOnly).to receive(:new).with(context).and_return(strategy)

      expect(output).to eq(%w[result])
      expect(DutyExpressionFormatter::Strategies::DescriptionOnly).to have_received(:new).with(context)
    end
  end

  context 'when the duty expression includes a description and amount' do
    let(:duty_expression_id) { '15' }

    it 'dispatches to the description-amount strategy' do
      allow(DutyExpressionFormatter::Strategies::DescriptionAmount).to receive(:new).with(context).and_return(strategy)

      expect(output).to eq(%w[result])
      expect(DutyExpressionFormatter::Strategies::DescriptionAmount).to have_received(:new).with(context)
    end
  end

  context 'when the duty expression falls through to the default path' do
    let(:duty_expression_id) { '66' }

    it 'dispatches to the default strategy' do
      allow(DutyExpressionFormatter::Strategies::Default).to receive(:new).with(context).and_return(strategy)

      expect(output).to eq(%w[result])
      expect(DutyExpressionFormatter::Strategies::Default).to have_received(:new).with(context)
    end
  end
end
