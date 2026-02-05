RSpec.describe SelfTextLookupService do
  around do |example|
    # Reset state between tests
    described_class.instance_variable_set(:@self_texts, nil)
    described_class.instance_variable_set(:@csv_path, nil)
    example.run
    described_class.instance_variable_set(:@self_texts, nil)
    described_class.instance_variable_set(:@csv_path, nil)
  end

  describe '.lookup' do
    context 'with valid CSV file' do
      before do
        allow(File).to receive(:exist?).and_return(true)
        allow(CSV).to receive(:foreach)
          .and_yield(CSV::Row.new(
                       %w[CN_CODE SelfText_EN SelfText_DE SelfText_FR],
                       ['0101210000', 'Pure-bred breeding horses', 'Reinrassige Zuchtpferde', 'Chevaux reproducteurs de race pure'],
                     ))
          .and_yield(CSV::Row.new(
                       %w[CN_CODE SelfText_EN SelfText_DE SelfText_FR],
                       ['0102 29 21', 'Live cattle weighing 80-160 kg', 'Lebende Rinder 80-160 kg', 'Bovins vivants 80-160 kg'],
                     ))
          .and_yield(CSV::Row.new(
                       %w[CN_CODE SelfText_EN SelfText_DE SelfText_FR],
                       ['8471300000', 'Portable digital computers', 'Tragbare Digitalrechner', 'Ordinateurs portables'],
                     ))
      end

      it 'returns the self-text for a matching code' do
        expect(described_class.lookup('0101210000')).to eq('Pure-bred breeding horses')
      end

      it 'normalizes codes with spaces and pads to 10 characters' do
        # '0102 29 21' becomes '0102292100' after normalization
        expect(described_class.lookup('0102292100')).to eq('Live cattle weighing 80-160 kg')
      end

      it 'returns nil for non-matching codes' do
        expect(described_class.lookup('9999999999')).to be_nil
      end
    end

    context 'when CSV file does not exist' do
      before do
        allow(File).to receive(:exist?).and_return(false)
      end

      it 'returns nil and logs a warning' do
        allow(Rails.logger).to receive(:warn)

        expect(described_class.lookup('0101210000')).to be_nil
        expect(Rails.logger).to have_received(:warn).with(/CSV not found/)
      end
    end

    context 'with blank codes or self-texts' do
      before do
        allow(File).to receive(:exist?).and_return(true)
        allow(CSV).to receive(:foreach)
          .and_yield(CSV::Row.new(%w[CN_CODE SelfText_EN], ['', 'Blank code entry']))
          .and_yield(CSV::Row.new(%w[CN_CODE SelfText_EN], ['1234567890', '']))
          .and_yield(CSV::Row.new(%w[CN_CODE SelfText_EN], ['9876543210', 'Valid entry']))
      end

      it 'skips entries with blank codes' do
        expect(described_class.lookup('')).to be_nil
      end

      it 'skips entries with blank self-texts' do
        expect(described_class.lookup('1234567890')).to be_nil
      end

      it 'returns valid entries' do
        expect(described_class.lookup('9876543210')).to eq('Valid entry')
      end
    end
  end

  describe '.reload!' do
    before do
      allow(File).to receive(:exist?).and_return(true)
      allow(CSV).to receive(:foreach)
        .and_yield(CSV::Row.new(%w[CN_CODE SelfText_EN], ['1111111111', 'First load']))
    end

    it 'clears cached data and reloads' do
      # First load
      described_class.lookup('1111111111')

      # Change the mock to return different data
      allow(CSV).to receive(:foreach)
        .and_yield(CSV::Row.new(%w[CN_CODE SelfText_EN], ['2222222222', 'Second load']))

      described_class.reload!

      expect(described_class.lookup('1111111111')).to be_nil
      expect(described_class.lookup('2222222222')).to eq('Second load')
    end
  end

  describe '.csv_path' do
    it 'defaults to the expected path' do
      expect(described_class.csv_path.to_s).to include('data/CN2026_SelfText_EN_DE_FR.csv')
    end
  end

  describe '.csv_path=' do
    it 'allows setting a custom path' do
      described_class.csv_path = '/custom/path.csv'
      expect(described_class.csv_path).to eq('/custom/path.csv')
    end

    it 'clears cached self-texts when path changes' do
      allow(File).to receive(:exist?).and_return(true)
      allow(CSV).to receive(:foreach)
        .and_yield(CSV::Row.new(%w[CN_CODE SelfText_EN], %w[1111111111 Cached]))

      described_class.lookup('1111111111') # Load cache

      described_class.csv_path = '/new/path.csv'

      expect(described_class.instance_variable_get(:@self_texts)).to be_nil
    end
  end

  describe '.loaded?' do
    it 'returns false before loading' do
      expect(described_class.loaded?).to be false
    end

    it 'returns true after loading with data' do
      allow(File).to receive(:exist?).and_return(true)
      allow(CSV).to receive(:foreach)
        .and_yield(CSV::Row.new(%w[CN_CODE SelfText_EN], ['1111111111', 'Test entry']))

      described_class.lookup('anything')

      expect(described_class.loaded?).to be true
    end
  end

  describe '.count' do
    before do
      allow(File).to receive(:exist?).and_return(true)
      allow(CSV).to receive(:foreach)
        .and_yield(CSV::Row.new(%w[CN_CODE SelfText_EN], ['1111111111', 'Entry 1']))
        .and_yield(CSV::Row.new(%w[CN_CODE SelfText_EN], ['2222222222', 'Entry 2']))
    end

    it 'returns the number of loaded self-texts' do
      expect(described_class.count).to eq(2)
    end
  end
end
