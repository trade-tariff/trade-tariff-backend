require 'rails_helper'

RSpec.describe News::Importer do
  subject(:instance) { described_class.new json_data }

  let(:json_data) { file_fixture 'news/govuk_stories.json' }

  describe '.assign_missing_slugs!' do
    subject { News::Item.all.pluck(:slug) }

    let(:items) { create_list :news_item, 3, :updates_page }

    context 'with slugs' do
      before do
        items
        described_class.assign_missing_slugs!
      end

      it { is_expected.to match_array items.pluck(:slug) }
    end

    context 'without slugs' do
      before do
        items
        News::Item.dataset.update(slug: nil)
        described_class.assign_missing_slugs!
      end

      it { is_expected.to all be_present }

      context 'with historical items' do
        let(:items) { create_list :news_item, 1, :updates_page, end_date: 1.day.ago }

        it { is_expected.to all be_nil }
      end

      context 'with future items' do
        let(:items) { create_list :news_item, 1, :updates_page, start_date: 1.week.from_now }

        it { is_expected.to all be_present }
      end

      context 'with non updates page items' do
        let(:items) { create_list :news_item, 1, :banner, show_on_updates_page: false }

        it { is_expected.to all be_nil }
      end

      context 'with duplicate titles' do
        let :items do
          [
            create(:news_item, :updates_page, title: 'test'),
            create(:news_item, :updates_page, title: 'test', slug: 'test-2'),
          ]
        end

        it { is_expected.to all be_present }
      end
    end
  end

  describe '.new' do
    it { is_expected.to be_instance_of described_class }
  end

  describe '#stories' do
    subject { instance.stories.length }

    it { is_expected.to be 3 }
  end

  describe '#import!' do
    it { expect { instance.import! }.to change(News::Item, :count).by(3) }
    it { expect(instance.import!).to be 3 }

    context 'with collection names' do
      subject { News::Collection.all.pluck(:name) }

      before { instance.import! }

      it { is_expected.to include 'Tariff notices' }
      it { is_expected.to include 'Tariff stop press' }
      it { is_expected.to include 'Trade news' }
      it { is_expected.to include 'Service updates' }
    end

    context 'with first story' do
      subject(:first_item) { News::Item.order(:id).first }

      before do
        freeze_time
        instance.import!
      end

      it { is_expected.to have_attributes title: /four-wheeled/ }
      it { is_expected.to have_attributes slug: /a-four-wheeled/ }
      it { is_expected.to have_attributes precis: /classification for a four-wheeled/ }
      it { is_expected.to have_attributes content: /^## New regulation/ }
      it { is_expected.to have_attributes start_date: Date.parse('2022-03-27') }
      it { is_expected.to have_attributes end_date: nil }
      it { is_expected.to have_attributes show_on_uk: true }
      it { is_expected.to have_attributes show_on_xi: true }
      it { is_expected.to have_attributes show_on_updates_page: true }
      it { is_expected.to have_attributes show_on_banner: false }
      it { is_expected.to have_attributes show_on_home_page: false }
      it { is_expected.to have_attributes imported_at: Time.zone.now }

      context 'with collections' do
        subject { first_item.collections }

        it { is_expected.to have_attributes length: 1 }
        it { is_expected.to all have_attributes name: 'Tariff notices' }
        it { is_expected.to all have_attributes slug: 'tariff_notices' }
      end

      context 'with tariff notices collection' do
        subject { News::Collection.where(slug: 'tariff_notices').first }

        it { is_expected.to have_attributes published: false }
      end
    end

    context 'when collection does not exist' do
      subject { News::Collection.all.pluck(:name) }

      before { instance.import! }

      let(:json_data) { StringIO.new story_with_unknown_collection.to_json }

      let :story_with_unknown_collection do
        {
          news: [
            {
              headline: 'story',
              slug: 'slug',
              precis: 'precis',
              story: 'content',
              validity_start_date: 5.minutes.ago.iso8601,
              validity_end_date: nil,
              themes: '{"Unknown collection"}',
            },
          ],
        }
      end

      it { is_expected.to include 'Unknown collection' }
    end

    context 'with end_dated story' do
      subject { News::Item.order(:id).last }

      before { instance.import! }

      it { is_expected.to have_attributes end_date: Date.parse('2020-10-12') }
    end

    context 'with XI service' do
      before { allow(TradeTariffBackend).to receive(:service).and_return 'xi' }

      it { expect { instance.import! }.to raise_exception described_class::NotAvailableOnXi }
    end

    context 'with incomplete story' do
      let(:json_data) { StringIO.new incomplete_data.to_json }

      let :incomplete_data do
        {
          news: [
            { title: 'incomplete story', slug: 'incomplete-story' },
          ],
        }
      end

      it { expect { instance.import! }.to raise_exception described_class::InvalidData }
    end
  end
end