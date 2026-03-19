RSpec.describe Reporting do
  let(:cdn_host) { 'https://reporting.trade-tariff.service.gov.uk' }
  let(:object_key) { 'uk/reporting/2026/03/19/commodities_uk_2026_03_19.csv' }
  let(:cdn_url) { File.join(cdn_host, object_key) }

  before do
    allow(TradeTariffBackend).to receive(:reporting_cdn_host).and_return(cdn_host)
  end

  describe '.get_published' do
    before do
      stub_request(:get, cdn_url).to_return(status: 200, body: 'csv-data')
    end

    it 'fetches report content from the reporting CDN' do
      expect(described_class.get_published(object_key)).to eq('csv-data')
    end
  end

  describe '.published_link' do
    it 'returns the reporting CDN URL' do
      expect(described_class.published_link(object_key)).to eq(cdn_url)
    end
  end

  describe '.published_exist?' do
    context 'when the report exists on the CDN' do
      before do
        stub_request(:head, cdn_url).to_return(status: 200)
      end

      it { expect(described_class.published_exist?(object_key)).to be(true) }
    end

    context 'when the report is missing from the CDN' do
      before do
        stub_request(:head, cdn_url).to_return(status: 404)
      end

      it { expect(described_class.published_exist?(object_key)).to be(false) }
    end
  end
end
