RSpec.describe TradeTariffBackend do
  describe '.api_version' do
    let(:request) { instance_double(ActionDispatch::Request) }

    context 'when Accept header specifies a version' do
      before { allow(request).to receive(:headers).and_return({ 'Accept' => 'application/vnd.uktt.v2' }) }

      it 'extracts the version number' do
        expect(described_class.api_version(request)).to eq('2')
      end
    end

    context 'when Accept header is absent' do
      before { allow(request).to receive(:headers).and_return({}) }

      it 'defaults to version 1' do
        expect(described_class.api_version(request)).to eq('1')
      end
    end
  end

  describe '.user_agent' do
    before { described_class.instance_variable_set(:@revision, nil) }

    it 'includes TradeTariffBackend prefix' do
      expect(described_class.user_agent).to start_with('TradeTariffBackend/')
    end
  end

  describe '.data_migration_path' do
    it 'points to db/data_migrations under Rails root' do
      expect(described_class.data_migration_path).to eq(Rails.root.join('db/data_migrations'))
    end
  end

  describe '.stop_words_file' do
    it 'points to db/stop_words.yml under Rails root' do
      expect(described_class.stop_words_file).to eq(Rails.root.join('db/stop_words.yml'))
    end
  end

  describe '.change_count' do
    it 'returns 10' do
      expect(described_class.change_count).to eq(10)
    end
  end

  describe '.revision' do
    before { described_class.instance_variable_set(:@revision, nil) }

    context 'when REVISION file exists' do
      before do
        allow(File).to receive(:file?).with('REVISION').and_return(true)
        allow(File).to receive(:read).with('REVISION').and_return("abc123\n")
      end

      it 'returns the trimmed revision string' do
        expect(described_class.revision).to eq('abc123')
      end
    end

    context 'when REVISION file does not exist' do
      before { allow(File).to receive(:file?).with('REVISION').and_return(false) }

      it 'returns nil' do
        expect(described_class.revision).to be_nil
      end
    end

    context 'when REVISION file is not readable' do
      before do
        allow(File).to receive(:file?).with('REVISION').and_return(true)
        allow(File).to receive(:read).with('REVISION').and_raise(Errno::EACCES)
      end

      it 'returns nil' do
        expect(described_class.revision).to be_nil
      end
    end
  end
end
