RSpec.describe TradesetDescriptionPopulatorService do
  describe '#call' do
    subject(:call) { described_class.new.call }

    let(:file_path) { 'spec/fixtures/tradeset_descriptions/DEC2022SAMPLE.csv' }

    before do
      allow(TariffSynchronizer::FileService).to receive(:list_by).and_return([{ path: file_path }])
      allow(TariffSynchronizer::FileService).to receive(:download_and_gunzip).and_return([file_path])
    end

    it 'creates tradeset descriptions' do
      expect { call }.to change(TradesetDescription, :count).by(3)
    end

    it 'sets classification date' do
      call

      expect(TradesetDescription).to all(have_attributes(classification_date: Date.parse('2022-12-31')))
    end

    it 'sets filename' do
      call

      expect(TradesetDescription).to all(have_attributes(filename: 'DEC2022SAMPLE.csv'))
    end

    it 'sets created_at' do
      call

      expect(TradesetDescription).to all(have_attributes(created_at: be_present))
    end

    it 'sets updated_at' do
      call

      expect(TradesetDescription).to all(have_attributes(updated_at: be_present))
    end
  end
end
