RSpec.describe HeadingService::PrecacheService do
  before do
    allow(TradeTariffBackend).to receive(:nested_set_headings?).and_return ns_heading
    allow(Rails).to receive(:cache).and_return cache

    commodity
  end

  let(:ns_heading) { true }
  let(:cache) { instance_double 'Rails.cache', write: true }
  let(:commodity) { create :commodity, :with_chapter_and_heading, :with_children }

  let :heading_key do
    HeadingService::HeadingSerializationService
      .cache_key(commodity.heading, Time.zone.today, false, {})
  end

  describe '#call' do
    before { described_class.new(Time.zone.today).call }

    it 'caches heading' do
      expect(cache).to have_received(:write).with(heading_key,
                                                  hash_including(:data),
                                                  expires_in: 23.hours)
    end

    context 'with nested set headings disabled' do
      let(:ns_heading) { false }

      it { expect(cache).not_to have_received(:write).with(heading_key, any_args) }
    end
  end
end
