RSpec.describe GreenLanes::ExemptingAdditionalCodeOverride do
  describe '#reference_additional_code' do
    subject { exempting_additional_code_override.reload.reference_additional_code }

    let(:exempting_additional_code_override) { create :exempting_additional_code_override, reference_additional_code: }
    let(:reference_additional_code) { create :additional_code }

    it { is_expected.to eq reference_additional_code }
  end

  describe 'category_assessment timestamps' do
    subject { assessment.reload.updated_at }

    let(:override) { create :exempting_additional_code_override }
    let(:assessment) { create :category_assessment, updated_at: 20.minutes.ago }

    before do
      override && assessment
      override.update additional_code_type_id: '9'
    end

    it { is_expected.to be_within(1.minute).of Time.zone.now }
  end
end
