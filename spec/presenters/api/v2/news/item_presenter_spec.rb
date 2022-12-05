RSpec.describe Api::V2::News::ItemPresenter do
  subject(:presented) { described_class.new news_item }

  let :news_item do
    item = create :news_item
    item.add_collection unpublished
    item.add_collection published
    item.reload
  end

  let(:unpublished) { create(:news_collection, :unpublished) }
  let(:published) { create(:news_collection) }

  describe '#collection_ids' do
    subject { presented.collection_ids }

    it { is_expected.to include published.id }
    it { is_expected.not_to include unpublished.id }
  end

  describe '#collections' do
    subject { presented.collections }

    it { is_expected.to include published }
    it { is_expected.not_to include unpublished }
  end

  describe '.wrap' do
    subject { described_class.wrap items }

    let(:items) { create_list :news_item, 3, :with_collections }

    it { is_expected.to all be_instance_of described_class }
  end
end
