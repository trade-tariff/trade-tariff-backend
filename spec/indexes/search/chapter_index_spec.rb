RSpec.describe Search::ChapterIndex do
  subject(:instance) { described_class.new 'testnamespace' }

  it { is_expected.to have_attributes type: 'chapter' }
  it { is_expected.to have_attributes name: 'testnamespace-chapters-uk' }
  it { is_expected.to have_attributes name_without_namespace: 'ChapterIndex' }
  it { is_expected.to have_attributes model_class: Chapter }
  it { is_expected.to have_attributes serializer: Search::ChapterSerializer }

  describe '#serialize_record' do
    subject { instance.serialize_record record }

    let(:record) { create :chapter }

    it { is_expected.to include 'id' => record.goods_nomenclature_sid }
    it { is_expected.to include 'description' => record.description.presence }
  end
end
