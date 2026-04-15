RSpec.describe Search::CommodityIndex do
  subject(:instance) { described_class.new 'testnamespace' }

  it { is_expected.to have_attributes type: 'commodity' }
  it { is_expected.to have_attributes name: 'testnamespace-commodities-uk' }
  it { is_expected.to have_attributes name_without_namespace: 'CommodityIndex' }
  it { is_expected.to have_attributes model_class: Commodity }
  it { is_expected.to have_attributes serializer: Search::CommoditySerializer }

  describe '#serialize_record' do
    subject { instance.serialize_record record }

    let(:record) { create :commodity }

    it { is_expected.to include 'id' => record.goods_nomenclature_sid }
  end
end
