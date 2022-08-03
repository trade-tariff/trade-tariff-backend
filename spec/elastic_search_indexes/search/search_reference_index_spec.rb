require 'rails_helper'

RSpec.describe Search::SearchReferenceIndex do
  subject(:index) { described_class.new 'testnamespace' }

  let(:record) { create(:search_reference) }

  it { is_expected.to have_attributes type: 'search_reference' }
  it { is_expected.to have_attributes name: 'testnamespace-search_references' }
  it { is_expected.to have_attributes name_without_namespace: 'SearchReferenceIndex' }
  it { is_expected.to have_attributes model_class: SearchReference }
  it { is_expected.to have_attributes serializer: Search::SearchReferenceSerializer }

  describe '#serialize_record' do
    subject { index.serialize_record(record) }

    it { is_expected.to include('title' => record.title) }
  end
end
