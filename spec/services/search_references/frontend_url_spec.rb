RSpec.describe SearchReferences::FrontendUrl do
  subject(:url) do
    described_class.call(referenced_class:, goods_nomenclature_item_id: '0101210000', productline_suffix: '10')
  end

  before { allow(TradeTariffBackend).to receive(:frontend_host).and_return('https://example.com/') }

  context 'when the reference is a chapter' do
    let(:referenced_class) { 'Chapter' }

    it { is_expected.to eq('https://example.com/chapters/01') }
  end

  context 'when the reference is a heading' do
    let(:referenced_class) { 'Heading' }

    it { is_expected.to eq('https://example.com/headings/0101') }
  end

  context 'when the reference is a subheading' do
    let(:referenced_class) { 'Subheading' }

    it { is_expected.to eq('https://example.com/subheadings/0101210000-10') }
  end

  context 'when the reference is a commodity' do
    let(:referenced_class) { 'Commodity' }

    it { is_expected.to eq('https://example.com/commodities/0101210000') }
  end

  context 'when the referenced class is not known' do
    let(:referenced_class) { 'Section' }

    it { is_expected.to be_nil }
  end

  context 'when no frontend host is configured' do
    let(:referenced_class) { 'Commodity' }

    before { allow(TradeTariffBackend).to receive(:frontend_host).and_return(nil) }

    it { is_expected.to be_nil }
  end
end
