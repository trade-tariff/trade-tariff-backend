require 'rails_helper'

RSpec.describe News::Importer do
  subject(:instance) { described_class.new json_data }

  let(:json_data) { file_fixture 'news/govuk_stories.json' }

  describe '.new' do
    it { is_expected.to be_instance_of described_class }
  end

  describe '#stories' do
    subject { instance.stories }

    it { is_expected.to have_attributes length: 3 }
  end

  describe '#import!' do
    it { expect { instance.import! }.to change(News::Item, :count).by(3) }
    it { expect(instance.import!).to be 3 }

    context 'with first story' do
      subject { News::Item.order(:id).first }

      before { instance.import! }

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
