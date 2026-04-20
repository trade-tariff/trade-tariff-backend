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
end
