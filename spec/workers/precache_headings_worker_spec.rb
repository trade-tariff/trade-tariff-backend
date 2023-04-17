RSpec.describe PrecacheHeadingsWorker, type: :worker do
  let(:date) { Time.zone.today }

  describe '#perform' do
    before do
      allow(TradeTariffBackend).to receive(:nested_set_headings?).and_return(true)
      allow(Rails.cache).to receive(:write).and_call_original

      heading

      described_class.new.perform date.to_formatted_s(:db)
    end

    let(:heading) { create :heading, :with_chapter, :with_children }

    let(:cache_key) do
      HeadingService::HeadingSerializationService.cache_key(heading, date, false, {})
    end

    it 'writes to cache' do
      expect(Rails.cache).to \
        have_received(:write).with(cache_key, hash_including(:data), any_args)
    end
  end
end
