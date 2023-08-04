RSpec.describe CertificateDescription do
  describe '.with_fuzzy_description' do
    subject(:with_fuzzy_description) { described_class.with_fuzzy_description(description) }

    before do
      create :certificate_description, description: 'VAT 20%'
      create :certificate_description, description: 'VAT 10%'
      create :certificate_description, description: 'VAT 5%'
      create :certificate_description, description: 'Excise 5%'
    end

    context 'when description is VAT lowercase' do
      let(:description) { 'vat' }

      it { expect(with_fuzzy_description.pluck(:description)).to all(include('VAT')) }
    end

    context 'when description is VAT upper case' do
      let(:description) { 'VAT' }

      it { expect(with_fuzzy_description.pluck(:description)).to all(include('VAT')) }
    end

    context 'when description is 5%' do
      let(:description) { '5%' }

      it { expect(with_fuzzy_description.pluck(:description)).to all(include('5%')) }
    end
  end
end
