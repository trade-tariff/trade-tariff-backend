require 'rails_helper'

RSpec.describe News::Item do
  describe 'attributes' do
    it { is_expected.to respond_to :start_date }
    it { is_expected.to respond_to :end_date }
    it { is_expected.to respond_to :title }
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
  end

  describe 'associations' do
    describe '#collections' do
      subject { described_class.where(id: item.id).take.collections.pluck(:id) }

      before { collections.each(&item.method(:add_collection)) }

      let(:item) { create :news_item }

      let :collections do
        [
          create(:news_collection, name: 'BBB'),
          create(:news_collection, name: 'AAA'),
        ]
      end

      it { is_expected.to eq collections.map(&:id).reverse }

      context 'with priorities' do
        before { item.add_collection priority }

        let(:priority) { create(:news_collection, name: 'CCC', priority: 1) }

        let :high_then_low_priority_collection_ids do
          [priority.id] + collections.map(&:id).reverse
        end

        it { is_expected.to eq high_then_low_priority_collection_ids }
      end
    end

    describe '#collection_ids' do
      subject { item.collection_ids }

      before do
        collections.each(&item.method(:add_collection))
        item.reload
      end

      let(:item) { create :news_item }
      let(:collections) { create_pair :news_collection }

      it { is_expected.to match_array collections.map(&:id) }

      context 'with newly assigned ids' do
        before { item.collection_ids = [999_999] }

        it { is_expected.to match_array [999_999] }
      end

      context 'with extended ids list' do
        before { item.collection_ids += [999_999] }

        it { is_expected.to match_array collections.map(&:id) + [999_999] }
      end

      context 'with appended ids list' do
        before { item.collection_ids << 999_999 }

        it { is_expected.to match_array collections.map(&:id) + [999_999] }
      end

      context 'when saving' do
        let(:another) { create :news_collection }

        before do
          item.collection_ids = [collections.first.id, another.id]
          item.save.reload
        end

        it { is_expected.to match_array [collections.first.id, another.id] }
      end
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
        inside_collection
        outside_collection
      end

      let(:inside_collection) { create :news_item, :with_collections, title: 'in' }
      let(:outside_collection) { create :news_item, title: 'out' }

      context 'without collection' do
        subject { described_class.for_collection(nil).all }

        it { is_expected.to include inside_collection }
        it { is_expected.to include outside_collection }
      end

      context 'with known collection' do
        subject do
          described_class.for_collection(inside_collection.collections.first.id.to_s).all
        end

        it { is_expected.to include inside_collection }
        it { is_expected.not_to include outside_collection }
      end

      context 'with unknown collection' do
        subject do
          described_class.for_collection('0').all
        end

        it { is_expected.not_to include inside_collection }
        it { is_expected.not_to include outside_collection }
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
end
