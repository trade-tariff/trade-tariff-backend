RSpec.describe SetRequestedService do
  subject(:middleware) { described_class.new(app) }

  let(:app) { ->(_env) { [200, {}, []] } }
  let(:env) { Rack::MockRequest.env_for(path) }

  after { TradeTariffRequest.reset }

  describe '#call' do
    context 'with a /uk/ prefixed path' do
      let(:path) { '/uk/api/sections' }

      it 'sets TradeTariffRequest.service to uk' do
        middleware.call(env)

        expect(TradeTariffRequest.service).to eq('uk')
      end
    end

    context 'with a /xi/ prefixed path' do
      let(:path) { '/xi/api/commodities/0101000000' }

      it 'sets TradeTariffRequest.service to xi' do
        middleware.call(env)

        expect(TradeTariffRequest.service).to eq('xi')
      end
    end

    context 'with a non-service path' do
      let(:path) { '/healthcheckz' }

      it 'sets TradeTariffRequest.service to nil' do
        middleware.call(env)

        expect(TradeTariffRequest.service).to be_nil
      end
    end

    it 'passes the request to the next middleware' do
      test_env = Rack::MockRequest.env_for('/uk/api/sections')

      allow(app).to receive(:call).and_return([200, {}, []])
      middleware.call(test_env)

      expect(app).to have_received(:call).with(test_env)
    end
  end
end
