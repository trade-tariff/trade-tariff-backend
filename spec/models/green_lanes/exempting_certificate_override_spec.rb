RSpec.describe GreenLanes::ExemptingCertificateOverride do
  describe 'attributes' do
    it { is_expected.to respond_to :id }
    it { is_expected.to respond_to :certificate_type_code }
    it { is_expected.to respond_to :certificate_code }
    it { is_expected.to respond_to :created_at }
    it { is_expected.to respond_to :updated_at }
  end

  describe 'validations' do
    subject(:errors) { instance.tap(&:valid?).errors }

    let(:instance) { described_class.new }

    it { is_expected.to include certificate_type_code: ['is not present'] }
    it { is_expected.to include certificate_code: ['is not present'] }

    context 'with duplicate certificate_type_code and certificate_code' do
      let(:existing) { create :exempting_certificate_override }

      let :instance do
        described_class.new certificate_type_code: existing.certificate_type_code,
                            certificate_code: existing.certificate_code
      end

      it { is_expected.to include %i[certificate_code certificate_type_code] => ['is already taken'] }
    end
  end

  describe 'date fields' do
    subject { create(:exempting_certificate_override).reload }

    it { is_expected.to have_attributes created_at: be_within(1.minute).of(Time.zone.now) }
    it { is_expected.to have_attributes updated_at: be_within(1.minute).of(Time.zone.now) }
  end

  describe 'associations' do
    describe '#certificate' do
      subject { exempting_certificate_override.reload.certificate }

      let(:exempting_certificate_override) { create :exempting_certificate_override, certificate: }
      let(:certificate) { create :certificate }

      it { is_expected.to eq certificate }
    end
  end
end
