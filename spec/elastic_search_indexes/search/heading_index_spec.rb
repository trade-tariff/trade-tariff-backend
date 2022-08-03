require 'rails_helper'

RSpec.describe Search::HeadingIndex do
  subject(:index) { described_class.new 'testnamespace' }

  let(:record) { create(:heading) }

  it { is_expected.to have_attributes type: 'heading' }
  it { is_expected.to have_attributes name: 'testnamespace-headings' }
  it { is_expected.to have_attributes name_without_namespace: 'HeadingIndex' }
  it { is_expected.to have_attributes model_class: Heading }
  it { is_expected.to have_attributes serializer: Search::HeadingSerializer }

  describe '#serialize_record' do
    subject { index.serialize_record(record) }

    it { is_expected.to include 'id' => record.goods_nomenclature_sid }
  end

  describe '#skip?' do
    it { expect(index.skip?(record)).to be(false) }
  end
end
