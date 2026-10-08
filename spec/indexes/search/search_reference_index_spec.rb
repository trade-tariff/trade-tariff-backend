RSpec.describe Search::SearchReferenceIndex do
  subject(:instance) { described_class.new 'testnamespace' }

  it { is_expected.to have_attributes type: 'search_reference' }
  it { is_expected.to have_attributes name: 'testnamespace-search_references-uk' }
  it { is_expected.to have_attributes name_without_namespace: 'SearchReferenceIndex' }
  it { is_expected.to have_attributes model_class: SearchReference }
  it { is_expected.to have_attributes serializer: Search::SearchReferenceSerializer }

  describe '#serialize_record' do
    subject { instance.serialize_record record }

    let(:record) { create :search_reference }

    it { is_expected.to include 'title' => record.title }
  end

  describe '#dataset' do
    let!(:search_usage) { create :search_reference }

    before { create :search_reference, usage: 'fpo' }

    it 'excludes fpo search references' do
      expect(instance.dataset.all).to eq([search_usage])
    end

    it 'counts pages from search references only' do
      expect(instance.total_pages).to eq(1)
    end
  end
end
