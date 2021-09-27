RSpec.describe MeursingMeasure do
  it { expect(described_class.primary_key).to eq(:measure_sid) }

  describe '#current?' do
    subject(:meursing_measure) { build(:meursing_measure, validity_end_date: validity_end_date, base_regulation_effective_end_date: validity_end_date) }

    around { |example| TimeMachine.now { example.run } }

    context 'when the validity end date is null' do
      let(:validity_end_date) { nil }

      it { is_expected.to be_current }
    end

    context 'when the validity end date is equal to or after the current point in time' do
      let(:validity_end_date) { Time.zone.tomorrow }

      it { is_expected.to be_current }
    end

    context 'when the validity end date is before the current point in time' do
      let(:validity_end_date) { Time.zone.yesterday }

      it { is_expected.not_to be_current }
    end
  end
end
