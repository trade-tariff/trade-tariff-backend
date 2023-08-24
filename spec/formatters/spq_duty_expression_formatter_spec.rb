RSpec.describe SpqDutyExpressionFormatter do
  describe '.format' do
    subject(:format) { described_class.format(component) }

    let(:component) { create(:measure_condition_component, duty_amount: 5) }

    it { is_expected.to eq('(£5.00 - SPR discount) / vol% / hl') }
  end
end
