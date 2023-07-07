RSpec.describe TradesetDescriptionPopulatorService do
  describe '#call' do
    subject(:call) { described_class.new.call }

    let(:file_path) { 'spec/fixtures/tradeset_descriptions/DEC22SAMPLE.csv' }

    before do
      allow(TariffSynchronizer::FileService).to receive(:list_by).and_return([{ path: file_path }])
      allow(TariffSynchronizer::FileService).to receive(:download_and_unzip).and_return([file_path])
    end

    it 'creates tradeset descriptions' do
      expect { call }.to change(TradesetDescription, :count).by(3)
    end

    it 'sets classification date' do
      call

      expect(TradesetDescription.last.classification_date).to eq(Date.parse('2022-12-31'))
    end

    it 'sets filename' do
      call

      expect(TradesetDescription.last.filename).to eq('DEC22SAMPLE.csv')
    end

    it 'sets created_at' do
      call

      expect(TradesetDescription.last.created_at).to be_present
    end

    it 'sets updated_at' do
      call

      expect(TradesetDescription.last.updated_at).to be_present
    end
  end
end
