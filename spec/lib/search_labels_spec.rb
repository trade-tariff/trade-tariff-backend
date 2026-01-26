RSpec.describe SearchLabels do
  describe '.with_labels' do
    it 'enables labels within the block' do
      described_class.with_labels do
        expect(described_class.enabled?).to be true
      end
    end

    it 'restores previous state after block' do
      expect(described_class.enabled?).to be false

      described_class.with_labels do
        expect(described_class.enabled?).to be true
      end

      expect(described_class.enabled?).to be false
    end

    it 'requires a block' do
      expect { described_class.with_labels }.to raise_error(ArgumentError, 'requires a block')
    end
  end

  describe '.without_labels' do
    it 'disables labels within the block' do
      described_class.with_labels do
        described_class.without_labels do
          expect(described_class.enabled?).to be false
        end
      end
    end

    it 'restores previous state after block' do
      described_class.with_labels do
        expect(described_class.enabled?).to be true

        described_class.without_labels do
          expect(described_class.enabled?).to be false
        end

        expect(described_class.enabled?).to be true
      end
    end

    it 'requires a block' do
      expect { described_class.without_labels }.to raise_error(ArgumentError, 'requires a block')
    end
  end

  describe '.enabled?' do
    it 'returns false by default' do
      expect(described_class.enabled?).to be false
    end

    it 'returns true when enabled' do
      described_class.with_labels do
        expect(described_class.enabled?).to be true
      end
    end
  end

  describe '.disabled?' do
    it 'returns true by default' do
      expect(described_class.disabled?).to be true
    end

    it 'returns false when labels are enabled' do
      described_class.with_labels do
        expect(described_class.disabled?).to be false
      end
    end
  end
end
