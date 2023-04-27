RSpec.describe HeadingService::PrecacheService do
  before do
    allow(TradeTariffBackend).to receive(:nested_set_headings?).and_return ns_heading
    allow(TradeTariffBackend).to receive(:nested_set_subheadings?).and_return ns_subheading
    allow(Rails.cache).to receive(:write).and_call_original
    allow(Rails.cache).to receive(:fetch).and_call_original

    commodity
  end

  let(:ns_heading) { true }
  let(:ns_subheading) { true }
  let(:commodity) { create :commodity, :with_chapter_and_heading, :with_children }

  let :heading_key do
    HeadingService::HeadingSerializationService
      .cache_key(commodity.heading, Time.zone.today, false, {})
  end

  let :subheading_key do
    CachedSubheadingService.new(commodity, Time.zone.today, use_nested_set: true).cache_key
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

    context 'with nested set headings disabled' do
      let(:ns_heading) { false }

      it { expect(Rails.cache).not_to have_received(:write).with(heading_key, any_args) }
      it { expect(Rails.cache).to have_received(:fetch).with(subheading_key, any_args) }
    end

    context 'with nested set subheadings disabled' do
      let(:ns_subheading) { false }

      it { expect(Rails.cache).to have_received(:write).with(heading_key, any_args) }
      it { expect(Rails.cache).not_to have_received(:fetch).with(subheading_key, any_args) }
    end
  end
end
