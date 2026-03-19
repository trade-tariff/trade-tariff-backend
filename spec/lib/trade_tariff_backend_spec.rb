RSpec.describe TradeTariffBackend do
  describe '.reporting_cdn_host' do
    around do |example|
      original_environment = ENV['ENVIRONMENT']
      original_reporting_cdn_host = ENV['REPORTING_CDN_HOST']
      example.run
    ensure
      ENV['ENVIRONMENT'] = original_environment
      ENV['REPORTING_CDN_HOST'] = original_reporting_cdn_host
    end

    context 'when REPORTING_CDN_HOST is set' do
      before do
        ENV['ENVIRONMENT'] = 'production'
        ENV['REPORTING_CDN_HOST'] = 'https://custom.example.com'
      end

      it 'prefers the explicit environment variable' do
        expect(described_class.reporting_cdn_host).to eq('https://custom.example.com')
      end
    end

    context 'when ENVIRONMENT is production' do
      before do
        ENV['ENVIRONMENT'] = 'production'
        ENV.delete('REPORTING_CDN_HOST')
      end

      it 'returns the production reporting host' do
        expect(described_class.reporting_cdn_host).to eq('https://reporting.trade-tariff.service.gov.uk')
      end
    end

    context 'when ENVIRONMENT is staging' do
      before do
        ENV['ENVIRONMENT'] = 'staging'
        ENV.delete('REPORTING_CDN_HOST')
      end

      it 'returns the staging reporting host' do
        expect(described_class.reporting_cdn_host).to eq('https://reporting.staging.trade-tariff.service.gov.uk')
      end
    end

    context 'when ENVIRONMENT is development' do
      before do
        ENV['ENVIRONMENT'] = 'development'
        ENV.delete('REPORTING_CDN_HOST')
      end

      it 'returns the development reporting host' do
        expect(described_class.reporting_cdn_host).to eq('https://reporting.dev.trade-tariff.service.gov.uk')
      end
    end
  end
end
