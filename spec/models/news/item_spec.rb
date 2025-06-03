require 'rails_helper'

RSpec.describe News::Item do
  describe 'attributes' do
    it { is_expected.to respond_to :start_date }
    it { is_expected.to respond_to :end_date }
    it { is_expected.to respond_to :title }
    it { is_expected.to respond_to :slug }
    it { is_expected.to respond_to :precis }
    it { is_expected.to respond_to :content }
    it { is_expected.to respond_to :display_style }
    it { is_expected.to respond_to :show_on_xi }
    it { is_expected.to respond_to :show_on_uk }
    it { is_expected.to respond_to :show_on_home_page }
    it { is_expected.to respond_to :show_on_updates_page }
  end

  describe 'validations' do
    subject(:errors) { instance.tap(&:valid?).errors }

    let(:instance) { described_class.new }

    it { is_expected.to include(title: ['is not present']) }
    it { is_expected.to include(content: ['is not present']) }
    it { is_expected.not_to include(precis: ['is not present']) }
    it { is_expected.to include(display_style: ['is not present']) }
    it { is_expected.to include(show_on_uk: ['is not present']) }
    it { is_expected.to include(show_on_xi: ['is not present']) }
    it { is_expected.to include(show_on_updates_page: ['is not present']) }
    it { is_expected.to include(show_on_home_page: ['is not present']) }
    it { is_expected.to include(start_date: ['is not present']) }
    it { is_expected.not_to include(end_date: ['is not present']) }

    context 'with blank strings' do
      let(:instance) { described_class.new title: '', content: '' }

      it { is_expected.to include(title: ['is not present']) }
      it { is_expected.to include(content: ['is not present']) }
    end

    context 'with duplicate slug' do
      before { create :news_item, slug: 'testing' }

      let(:instance) { described_class.new slug: 'testing' }

      it { is_expected.to include(slug: ['is already taken']) }
    end

    context 'when showing on updates page' do
      let(:instance) { described_class.new(show_on_updates_page: true) }

      it { is_expected.to include(precis: ['is not present']) }
    end

    context 'when chapters are invalid' do
      let(:instance) { described_class.new(chapters: '1234') }

      it { is_expected.to include(chapters: ['have an invalid format']) }
    end

    context 'when chapters are valid' do
      let(:instance) { described_class.new(chapters: '12 34') }

      it { is_expected.not_to include(chapters: ['have an invalid format']) }
    end

    context 'when chapters are empty' do
      let(:instance) { described_class.new(chapters: '') }

      it { is_expected.not_to include(chapters: ['have an invalid format']) }
    end
  end

  describe 'associations' do
    describe '#collections' do
      subject { described_class.where(id: item.id).take.collections.pluck(:id) }

      before { item.add_collection additional_collection }

      let(:item) { create :news_item }

      let(:additional_collection) { create(:news_collection, name: 'AAA') }

      it { is_expected.to include item.collections.first.id }
      it { is_expected.to include additional_collection.id }

      context 'with priorities' do
        before { item.add_collection priority }

        let(:priority) { create(:news_collection, name: 'CCC', priority: 1) }

        let :high_then_low_priority_collection_ids do
          [priority.id] + item.collections.map(&:id).without(priority.id).reverse
        end

        it { is_expected.to eq high_then_low_priority_collection_ids }
      end

      describe 'removing item which belongs to collection' do
        subject { described_class.all.pluck(:id) }

        before { news_item.destroy }

        let(:news_item) { create :news_item }

        it { is_expected.not_to include news_item.id }
      end
    end

    describe '#collection_ids' do
      subject { item.collection_ids }

      before { original_collection_ids }

      let(:item) { create :news_item, collection_count: 2 }
      let(:original_collection_ids) { item.collections.pluck(:id) }

      it { is_expected.to match_array original_collection_ids }

      context 'with newly assigned ids' do
        before { item.collection_ids = [999_999] }

        it { is_expected.to contain_exactly(999_999) }
      end

      context 'with extended ids list' do
        before { item.collection_ids += [999_999] }

        it { is_expected.to match_array original_collection_ids + [999_999] }
      end

      context 'with appended ids list' do
        before { item.collection_ids << 999_999 }

        it { is_expected.to match_array original_collection_ids + [999_999] }
      end

      context 'when saving' do
        let(:new_collection) { create :news_collection }

        before do
          item.collection_ids = [original_collection_ids.first, new_collection.id]
          item.save.reload
        end

        it { is_expected.to contain_exactly(original_collection_ids.first, new_collection.id) }
      end
    end

    describe '#published_collections' do
      subject { described_class.first(id: item.id).published_collections.pluck(:name) }

      before { collections.each(&item.method(:add_collection)) }

      let(:item) { create :news_item }

      let :collections do
        [
          create(:news_collection, name: 'AAA'),
          create(:news_collection, :unpublished, name: 'BBB'),
        ]
      end

      it { is_expected.to include 'AAA' }
      it { is_expected.not_to include 'BBB' }
    end
  end

  describe 'scopes' do
    describe '.for_service' do
      subject(:results) { described_class.for_service(service_name) }

      let(:uk_page) { create :news_item, show_on_uk: true, show_on_xi: false }
      let(:xi_page) { create :news_item, show_on_uk: false, show_on_xi: true }
      let(:both_page) { create :news_item, show_on_uk: true, show_on_xi: true }
      let(:neither_page) { create :news_item, show_on_uk: false, show_on_xi: false }

      shared_examples_for 'a non-filtering service filter invocation' do |service_name|
        subject(:results) { described_class.for_service(service_name) }

        it { is_expected.to include uk_page }
        it { is_expected.to include xi_page }
        it { is_expected.to include both_page }
        it { is_expected.to include neither_page }
      end

      it_behaves_like 'a non-filtering service filter invocation', ''
      it_behaves_like 'a non-filtering service filter invocation', nil

      context 'with uk' do
        let(:service_name) { 'uk' }

        it { is_expected.to include uk_page }
        it { is_expected.not_to include xi_page }
        it { is_expected.to include both_page }
        it { is_expected.not_to include neither_page }
      end

      context 'with xi' do
        let(:service_name) { 'xi' }

        it { is_expected.to include xi_page }
        it { is_expected.not_to include uk_page }
        it { is_expected.to include both_page }
        it { is_expected.not_to include neither_page }
      end
    end

    describe '.for_target' do
      subject(:results) { described_class.for_target(target) }

      let(:updates_page) { create :news_item, :updates_page }
      let(:both_page) { create :news_item, :home_page, :updates_page }
      let(:neither_page) { create :news_item }

      context 'without target' do
        let(:target) { nil }

        it { is_expected.to include updates_page }
        it { is_expected.to include both_page }
        it { is_expected.to include neither_page }
      end

      context 'with home' do
        let(:target) { 'home' }
        let(:home_page) { create :news_item, :home_page }

        it { is_expected.to include home_page }
        it { is_expected.not_to include updates_page }
        it { is_expected.to include both_page }
        it { is_expected.not_to include neither_page }
      end

      context 'with updates' do
        let(:target) { 'updates' }
        let(:home_page) { create :news_item, :home_page }

        it { is_expected.to include updates_page }
        it { is_expected.not_to include home_page }
        it { is_expected.to include both_page }
        it { is_expected.not_to include neither_page }
      end

      context 'with banner' do
        let(:target) { 'banner' }
        let(:banner) { create :news_item, :banner }

        it { is_expected.to include banner }
        it { is_expected.not_to include updates_page }
        it { is_expected.not_to include both_page }
        it { is_expected.not_to include neither_page }
      end
    end

    describe '.for_today' do
      subject { described_class.for_today }

      let :yesterdays do
        create :news_item, start_date: Time.zone.yesterday, end_date: Time.zone.yesterday
      end

      let :todays do
        create :news_item, start_date: Time.zone.today, end_date: Time.zone.today
      end

      let :tomorrows do
        create :news_item, start_date: Time.zone.tomorrow, end_date: Time.zone.tomorrow
      end

      let :ongoing do
        create :news_item, start_date: Time.zone.today, end_date: nil
      end

      it { is_expected.not_to include yesterdays }
      it { is_expected.to include todays }
      it { is_expected.not_to include tomorrows }
      it { is_expected.to include ongoing }
    end

    describe '.for_year' do
      subject { described_class.for_year(year).all }

      before { twentytwo && twentythree }

      let(:twentytwo) { create :news_item, start_date: '2022-01-01' }
      let(:twentythree) { create :news_item, start_date: '2023-01-01' }

      context 'with year' do
        let(:year) { '2022' }

        it { is_expected.to include twentytwo }
        it { is_expected.not_to include twentythree }
      end

      context 'without year' do
        let(:year) { '' }

        it { is_expected.to include twentytwo }
        it { is_expected.to include twentythree }
      end
    end

    describe '.for_collection' do
      before do
        with_mixed_collections
        in_other_collection
      end

      let(:in_published_collection) { create :news_item, title: 'in' }
      let(:in_other_collection) { create :news_item, title: 'out' }

      let :in_unpublished_collection do
        create :news_item, title: 'unpublished', collection_traits: :unpublished
      end

      let :with_mixed_collections do
        create :news_item, title: 'mixed', collection_ids: [
          in_published_collection.published_collections.map(&:id).first,
          in_unpublished_collection.collections.map(&:id).first,
        ]
      end

      context 'without collection' do
        subject { described_class.for_collection(nil).all }

        it { is_expected.to include in_published_collection }
        it { is_expected.to include in_other_collection }
        it { is_expected.to include with_mixed_collections }
        it { is_expected.not_to include in_unpublished_collection }
      end

      context 'with known collection' do
        subject do
          collection_id = in_published_collection.published_collections.first.id.to_s
          described_class.for_collection(collection_id).all
        end

        it { is_expected.to include in_published_collection }
        it { is_expected.not_to include in_other_collection }
        it { is_expected.to include with_mixed_collections }
      end

      context 'with unpublished collection' do
        subject do
          collection_id = in_unpublished_collection.collections.first.id.to_s
          described_class.for_collection(collection_id).all
        end

        it { is_expected.to be_empty }
      end

      context 'with unknown collection' do
        subject { described_class.for_collection('0').all }

        it { is_expected.to be_empty }
      end

      context 'with slugs' do
        context 'with known collection' do
          subject do
            collection_slug = in_published_collection.collections.first.slug
            described_class.for_collection(collection_slug).all
          end

          it { is_expected.to include in_published_collection }
          it { is_expected.not_to include in_other_collection }
        end

        context 'with unknown slug' do
          subject { described_class.for_collection('random').all }

          it { is_expected.to be_empty }
        end
      end
    end

    describe '.descending' do
      subject { described_class.descending.to_a }

      let!(:published_today) { create :news_item, start_date: Time.zone.today }
      let!(:published_yesterday) { create :news_item, start_date: Time.zone.yesterday }

      it { is_expected.to eql [published_today, published_yesterday] }
    end
  end

  describe '.years' do
    subject { described_class.years }

    before do
      create :news_item, start_date: '2000-01-01'
      create :news_item, start_date: '2000-01-01'
      create :news_item, start_date: '2004-01-01'
      create :news_item, start_date: '2004-01-01', show_on_xi: false
      create :news_item, start_date: '2008-01-01', show_on_xi: false
    end

    it { is_expected.to eql [2008, 2004, 2000] }

    context 'with additional scope' do
      subject { described_class.for_service('xi').years }

      it { is_expected.to eql [2004, 2000] }
    end
  end

  describe '.latest_change' do
    subject { described_class.latest_change }

    before do
      older
      newer
      described_class.dataset.update(updated_at: :created_at)
    end

    let(:older) { create :news_item, created_at: 5.minutes.ago }
    let(:newer) { create :news_item, created_at: 3.minutes.ago }

    it { is_expected.to eq_pk newer }

    context 'when updating' do
      before do
        older.title = 'changed'
        older.save
      end

      it { is_expected.to eq_pk older }
    end

    context 'with unpublished' do
      before do
        unpublished

        described_class.dataset.update(updated_at: :created_at)
      end

      let :unpublished do
        create :news_item, start_date: 3.days.from_now,
                           created_at: 1.minute.ago
      end

      it { is_expected.to eq_pk unpublished }
    end
  end

  describe '#slug' do
    subject { instance.save.reload.slug }

    context 'when assigned' do
      let(:instance) { build :news_item, slug: 'testing' }

      it { is_expected.to eq 'testing' }
    end

    context 'when left blank' do
      let(:instance) { build :news_item, slug: '', title: 'Hello world' }

      it { is_expected.to eq 'hello-world' }
    end

    context 'with invalid slug' do
      let(:instance) { create :news_item, slug: 'Something/problematic' }

      it { is_expected.to eq 'somethingproblematic' }
    end

    context 'with overlong slug' do
      let(:title) { 'a' * (described_class::MAX_SLUG_LENGTH + 1) }
      let(:instance) { build :news_item, title: }

      it { is_expected.to eq 'a' * described_class::MAX_SLUG_LENGTH }
    end
  end

  describe '#emailable?' do
    subject { news_item.emailable? }

    context 'when notify_subscribers is false' do
      let(:news_item) { create :news_item, notify_subscribers: false }

      it { is_expected.to be false }
    end

    context 'when no collections are subscribable' do
      let(:news_item) { create :news_item, notify_subscribers: true }
      let(:collection) { create :news_collection, subscribable: false }

      before do
        news_item.add_collection(collection)
      end

      it { is_expected.to be false }
    end

    context 'when notify_subscribers is true and some collections are subscribable' do
      let(:news_item) { create :news_item, notify_subscribers: true }
      let(:collection) { create :news_collection, subscribable: true }

      before do
        news_item.add_collection(collection)
      end

      it { is_expected.to be true }
    end
  end

  describe '#public_url' do
    subject { news_item.public_url }

    let(:news_item) { create(:news_item, slug: 'tariff-stop-press-notice---22-may-2025') }
    let(:host) { 'https://www.trade-tariff.service.gov.uk/' }

    before do
      allow(TradeTariffBackend).to receive(:frontend_host).and_return(host)
    end

    it { is_expected.to eq 'https://www.trade-tariff.service.gov.uk/news/stories/tariff-stop-press-notice---22-may-2025' }
  end

  describe '#subscription_reason' do
    subject(:reason) { news_item.subscription_reason }

    context 'when chapters are present' do
      let(:news_item) { build(:news_item, chapters: '12') }

      it 'returns a chapter-specific subscription reason' do
        expect(reason).to eq 'You have previously subscribed to receive updates about this tariff chapter - 12'
      end
    end

    context 'when chapters are not present' do
      let(:news_item) { build(:news_item, chapters: nil) }

      it 'returns a non-chapter-specific subscription reason' do
        expect(reason).to eq 'This is a non-chapter specific update from the UK Trade Tariff Service'
      end
    end

    context 'when chapters are empty' do
      let(:news_item) { build(:news_item, chapters: '') }

      it 'returns a non-chapter-specific subscription reason' do
        expect(reason).to eq 'This is a non-chapter specific update from the UK Trade Tariff Service'
      end
    end
  end

  describe 'after_save callback' do
    let(:instance) { build(:news_item) }

    before do
      allow(StopPressSubscriptionWorker).to receive(:perform_async)
    end

    it 'calls worker on save' do
      instance.save
      expect(StopPressSubscriptionWorker).to have_received(:perform_async).with(instance.id)
    end

    it 'does not call worker when feature flag is off' do
      allow(TradeTariffBackend).to receive(:myott?).and_return(false)

      instance.save
      expect(StopPressSubscriptionWorker).not_to have_received(:perform_async).with(instance.id)
    end
  end
end
