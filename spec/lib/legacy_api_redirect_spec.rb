RSpec.describe LegacyApiRedirect do
  describe '#call' do
    let(:env) { Rack::MockRequest.env_for('/api/v2/sections') }

    it 'returns a response that follows the Rack 3 contract on its own' do
      expect { Rack::Lint.new(described_class.new).call(env) }.not_to raise_error
    end

    it 'still follows the Rack 3 contract after HandleGoodsNomenclature adds its headers' do
      app = Rack::Lint.new(HandleGoodsNomenclature.new(described_class.new))

      expect { app.call(env) }.not_to raise_error
    end
  end
end
