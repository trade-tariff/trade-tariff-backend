RSpec.describe Appendix5a do
  subject(:appendix_5a) { create(:appendix_5a) }

  it { is_expected.to respond_to(:updated_at) }
  it { is_expected.to respond_to(:created_at) }
  it { is_expected.to respond_to(:certificate_type_code) }
  it { is_expected.to respond_to(:certificate_code) }

  describe '.fetch_latest' do
    subject(:fetch_latest) { described_class.fetch_latest }

    include_context 'with a stubbed appendix 5a guidance s3 bucket'

    it { is_expected.to be_a(Hash) }
  end

  describe '#document_code' do
    subject(:document_code) { build(:appendix_5a, certificate_type_code: '1', certificate_code: '123').document_code }

    it { is_expected.to eq('1123') }
  end
end
