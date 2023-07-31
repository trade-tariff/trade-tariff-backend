RSpec.describe Api::V2::AdditionalCodeSearch::AdditionalCodePresenter do
  subject(:presented) { described_class.new news_item }

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

    let(:items) { create_list :news_item, 3 }

    it { is_expected.to all be_instance_of described_class }
  end
end
