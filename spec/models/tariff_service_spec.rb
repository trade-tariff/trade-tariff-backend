RSpec.describe TariffService do
  def with_service(value)
    original = ENV.fetch('SERVICE', nil)
    value.nil? ? ENV.delete('SERVICE') : ENV['SERVICE'] = value
    yield
  ensure
    original.nil? ? ENV.delete('SERVICE') : ENV['SERVICE'] = original
  end

  describe '.current' do
    it 'returns the SERVICE environment variable' do
      with_service('xi') { expect(described_class.current).to eq('xi') }
    end

    it 'defaults to uk when SERVICE is not set' do
      with_service(nil) { expect(described_class.current).to eq('uk') }
    end
  end

  describe '.uk?' do
    it 'is true for the uk service' do
      with_service('uk') { expect(described_class.uk?).to be(true) }
    end

    it 'is false for the xi service' do
      with_service('xi') { expect(described_class.uk?).to be(false) }
    end
  end

  describe '.xi?' do
    it 'is true for the xi service' do
      with_service('xi') { expect(described_class.xi?).to be(true) }
    end

    it 'is false for the uk service' do
      with_service('uk') { expect(described_class.xi?).to be(false) }
    end
  end

  describe 'TradeTariffBackend delegation' do
    it 'gives the same answer as TradeTariffBackend' do
      with_service('xi') do
        expect([TradeTariffBackend.service, TradeTariffBackend.uk?, TradeTariffBackend.xi?])
          .to eq([described_class.current, described_class.uk?, described_class.xi?])
      end
    end
  end
end
