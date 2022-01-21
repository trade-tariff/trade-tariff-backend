RSpec.describe TariffSynchronizer::TaricFileNameGeneratorPatched do
  describe '#url' do
    subject(:url) { described_class.new('TGB21258.xml').url }

    it { is_expected.to eq('http://example.com/taric/TGB21258.xml') }
  end
end
