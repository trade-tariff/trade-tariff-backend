RSpec.describe Certificate do
  describe '.with_certificate_types_and_codes' do
    subject(:dataset) { described_class.with_certificate_types_and_codes(certificate_types_and_codes) }

    before do
      create(
        :certificate,
        certificate_type_code: 'Y',
        certificate_code: '123',
      )
      create(
        :certificate,
        certificate_type_code: 'N',
        certificate_code: '456',
      )
      create(
        :certificate,
        certificate_type_code: 'Z',
        certificate_code: '789',
      )
    end

    context 'when certificate_types_and_codes is empty' do
      let(:certificate_types_and_codes) { [] }

      it 'applies no filter' do
        expect(dataset.pluck(:certificate_code)).to eq %w[123 456 789]
      end
    end

    context 'when certificate_types_and_codes is present' do
      let(:certificate_types_and_codes) do
        [
          %w[Y 123],
          %w[N 456],
        ]
      end

      it 'applies the filter' do
        expect(dataset.pluck(:certificate_code)).to eq %w[123 456]
      end
    end
  end

  describe '#special_nature?' do
    subject(:certificate) { build(:certificate, certificate_type_code:) }

    context 'when the certificate has a special nature type code' do
      let(:certificate_type_code) { 'A' }

      it { is_expected.to be_special_nature }
    end

    context 'when the certificate does not have a special nature type code' do
      let(:certificate_type_code) { 'X' }

      it { is_expected.not_to be_special_nature }
    end
  end

  describe '#authorised_use?' do
    subject(:certificate) { build(:certificate, certificate_type_code:, certificate_code:) }

    context 'when the certificate has a special nature type code' do
      let(:certificate_type_code) { 'N' }
      let(:certificate_code) { '990' }

      it { is_expected.to be_authorised_use }
    end

    context 'when the certificate does not have a special nature type code' do
      let(:certificate_type_code) { 'N' }
      let(:certificate_code) { '991' }

      it { is_expected.not_to be_authorised_use }
    end
  end
end
