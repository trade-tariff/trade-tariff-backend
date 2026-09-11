RSpec.describe Reporting do
  let(:cdn_host) { 'https://reporting.trade-tariff.service.gov.uk' }
  let(:object_key) { 'uk/reporting/2026/03/19/commodities_uk_2026_03_19.csv' }
  let(:cdn_url) { File.join(cdn_host, object_key) }
  let(:reporting_object) { instance_double(Aws::S3::Object) }

  before do
    allow(TradeTariffBackend).to receive(:reporting_cdn_host).and_return(cdn_host)
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
    allow(described_class).to receive(:object).with(object_key).and_return(reporting_object)
  end

  describe '.get_published' do
    context 'when the report is in the reporting bucket' do
      before do
        allow(reporting_object).to receive(:get).and_return(
          instance_double(Aws::S3::Types::GetObjectOutput, body: StringIO.new('csv-data')),
        )
      end

      it 'reads the report from S3' do
        expect(described_class.get_published(object_key)).to eq('csv-data')
      end

      it 'does not go out to the public reporting CDN' do
        described_class.get_published(object_key)

        expect(a_request(:any, cdn_url)).not_to have_been_made
      end
    end

    context 'when the report is missing from the reporting bucket' do
      before do
        allow(reporting_object).to receive(:get).and_raise(
          Aws::S3::Errors::NoSuchKey.new(nil, 'The specified key does not exist.'),
        )
      end

      it 'raises a fetch error naming the object key' do
        expect { described_class.get_published(object_key) }
          .to raise_error(Reporting::FetchError, /#{Regexp.escape(object_key)}/)
      end
    end

    context 'when S3 is unavailable' do
      before do
        allow(reporting_object).to receive(:get).and_raise(
          Aws::S3::Errors::ServiceUnavailable.new(nil, 'Service Unavailable'),
        )
      end

      it 'raises a fetch error naming the object key' do
        expect { described_class.get_published(object_key) }
          .to raise_error(Reporting::FetchError, /#{Regexp.escape(object_key)}/)
      end
    end
  end

  describe '.published_link' do
    it 'returns the reporting CDN URL, because the link is for a human to click' do
      expect(described_class.published_link(object_key)).to eq(cdn_url)
    end
  end

  describe '.published_exist?' do
    context 'when the report is in the reporting bucket' do
      before { allow(reporting_object).to receive(:exists?).and_return(true) }

      it { expect(described_class.published_exist?(object_key)).to be(true) }

      it 'does not go out to the public reporting CDN' do
        described_class.published_exist?(object_key)

        expect(a_request(:any, cdn_url)).not_to have_been_made
      end
    end

    context 'when the report is missing from the reporting bucket' do
      before { allow(reporting_object).to receive(:exists?).and_return(false) }

      it { expect(described_class.published_exist?(object_key)).to be(false) }
    end

    context 'when S3 returns an error' do
      before do
        allow(reporting_object).to receive(:exists?).and_raise(
          Aws::S3::Errors::ServiceUnavailable.new(nil, 'Service Unavailable'),
        )
      end

      it { expect(described_class.published_exist?(object_key)).to be(false) }
    end

    context 'when S3 cannot be reached' do
      before do
        allow(reporting_object).to receive(:exists?).and_raise(
          Seahorse::Client::NetworkingError.new(SocketError.new('getaddrinfo failed')),
        )
      end

      it { expect(described_class.published_exist?(object_key)).to be(false) }
    end
  end
end
