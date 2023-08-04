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
end
