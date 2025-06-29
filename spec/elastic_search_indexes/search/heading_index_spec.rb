RSpec.describe Search::HeadingIndex do
  subject(:instance) { described_class.new 'testnamespace' }

  it { is_expected.to have_attributes type: 'heading' }
  it { is_expected.to have_attributes name: 'testnamespace-headings-uk' }
  it { is_expected.to have_attributes name_without_namespace: 'HeadingIndex' }
  it { is_expected.to have_attributes model_class: Heading }
  it { is_expected.to have_attributes serializer: Search::HeadingSerializer }

  describe '#serialize_record' do
    subject { instance.serialize_record record }

    let(:record) { create :heading }

    it { is_expected.to include 'id' => record.goods_nomenclature_sid }
  end
end
