RSpec.describe Api::V2::GreenLanes::SubheadingSerializer do
  subject(:serialized) { described_class.new(subheading).serializable_hash[:data] }

  let(:subheading) { build :subheading }

  describe '#serializable_hash' do
    it { is_expected.to include type: :subheading  }
    it { is_expected.to include id: subheading.goods_nomenclature_sid.to_s  }

    context 'attributes' do
      subject {serialized[:attributes]}

      it { is_expected.to include goods_nomenclature_item_id: subheading.goods_nomenclature_item_id.to_s  }
    end
  end
end
