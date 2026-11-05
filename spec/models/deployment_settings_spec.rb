RSpec.describe DeploymentSettings do
  def with_env(name, value)
    original = ENV.fetch(name, nil)
    value.nil? ? ENV.delete(name) : ENV[name] = value
    yield
  ensure
    original.nil? ? ENV.delete(name) : ENV[name] = original
  end

  describe '.support_email' do
    it 'reads TARIFF_SUPPORT_EMAIL' do
      with_env('TARIFF_SUPPORT_EMAIL', 'support@example.com') do
        expect(described_class.support_email).to eq('support@example.com')
      end
    end

    it 'is nil when TARIFF_SUPPORT_EMAIL is not set' do
      with_env('TARIFF_SUPPORT_EMAIL', nil) { expect(described_class.support_email).to be_nil }
    end
  end

  describe '.frontend_host' do
    it 'reads FRONTEND_HOST' do
      with_env('FRONTEND_HOST', 'https://example.com') do
        expect(described_class.frontend_host).to eq('https://example.com')
      end
    end

    it 'is nil when FRONTEND_HOST is not set' do
      with_env('FRONTEND_HOST', nil) { expect(described_class.frontend_host).to be_nil }
    end
  end

  describe '.label_page_size' do
    it 'reads GOODS_NOMENCLATURE_LABEL_PAGE_SIZE as an integer' do
      with_env('GOODS_NOMENCLATURE_LABEL_PAGE_SIZE', '25') do
        expect(described_class.label_page_size).to eq(25)
      end
    end

    it 'defaults to 10' do
      with_env('GOODS_NOMENCLATURE_LABEL_PAGE_SIZE', nil) do
        expect(described_class.label_page_size).to eq(10)
      end
    end
  end

  describe '.environment' do
    it 'reads ENVIRONMENT as a string inquirer' do
      with_env('ENVIRONMENT', 'production') do
        expect(described_class.environment).to be_production
      end
    end

    it 'defaults to local' do
      with_env('ENVIRONMENT', nil) { expect(described_class.environment).to be_local }
    end
  end

  describe 'agreement with TradeTariffBackend' do
    it 'gives the same answers as TradeTariffBackend' do
      with_env('TARIFF_SUPPORT_EMAIL', 'a@example.com') do
        with_env('FRONTEND_HOST', 'https://example.com') do
          with_env('ENVIRONMENT', 'staging') do
            expect(
              [described_class.support_email, described_class.frontend_host, described_class.label_page_size, described_class.environment],
            ).to eq(
              [TradeTariffBackend.support_email, TradeTariffBackend.frontend_host, TradeTariffBackend.goods_nomenclature_label_page_size, TradeTariffBackend.environment],
            )
          end
        end
      end
    end
  end
end
