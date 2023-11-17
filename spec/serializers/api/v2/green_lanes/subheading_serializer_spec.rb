RSpec.describe Api::V2::GreenLanes::SubheadingSerializer do
  subject(:serialized) { described_class.new(subheading).serializable_hash[:data] }

  let(:subheading) { build :subheading }

  describe '#serializable_hash' do
    it { is_expected.to include type: :subheading }
    it { is_expected.to include id: subheading.goods_nomenclature_sid.to_s }

    context 'with attributes' do
      subject { serialized[:attributes] }

      it { is_expected.to include goods_nomenclature_item_id: subheading.goods_nomenclature_item_id.to_s }
      it { is_expected.to include description: subheading.description }
      it { is_expected.to include formatted_description: subheading.formatted_description }
      it { is_expected.to include validity_start_date: subheading.validity_start_date }
      it { is_expected.to include validity_end_date: subheading.validity_end_date }
      it { is_expected.to include description_plain: subheading.description_plain }
      it { is_expected.to include producline_suffix: subheading.producline_suffix }
    end
  end
end
