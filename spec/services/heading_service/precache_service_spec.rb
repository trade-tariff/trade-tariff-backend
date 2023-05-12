RSpec.describe HeadingService::PrecacheService do
  before do
    allow(Rails.cache).to receive(:write).and_call_original
    allow(Rails.cache).to receive(:fetch).and_call_original

    commodity
  end

  let(:commodity) { create :commodity, :with_chapter_and_heading, :with_children }

  let :heading_key do
    HeadingService::HeadingSerializationService
      .cache_key(commodity.heading, Time.zone.today, false, {})
  end

  let :subheading_key do
    CachedSubheadingService.new(commodity, Time.zone.today).cache_key
  end

  describe '#call' do
    before { described_class.new(Time.zone.today).call }

    it 'caches heading' do
      expect(Rails.cache).to have_received(:write).with(heading_key,
                                                        hash_including(:data),
                                                        expires_in: 23.hours)
    end

    it 'caches subheading' do
      expect(Rails.cache).to have_received(:fetch).with(subheading_key,
                                                        expires_in: 23.hours)
    end
  end
end
