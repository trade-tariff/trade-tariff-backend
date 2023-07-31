RSpec.describe Api::V2::AdditionalCodeSearch::AdditionalCodePresenter do
  subject(:presented) { described_class.new(additional_code, goods_nomenclatures) }

  let(:additional_code) { build :additional_code, additional_code_sid: 1 }
  let(:goods_nomenclatures) { build_list :goods_nomenclature, 1, goods_nomenclature_sid: 1 }

  describe '#goods_nomenclature_ids' do
    it { expect(presented.goods_nomenclature_ids).to eq [1] }
  end

  describe '#goods_nomenclatures' do
    it { expect(presented.goods_nomenclatures).to eq goods_nomenclatures }
  end

  describe '.wrap' do
    subject(:wrapped) { described_class.wrap(additional_codes, grouped_goods_nomenclatures) }

    let(:additional_codes) { build_list :additional_code, 1, additional_code_sid: 1 }
    let(:goods_nomenclatures) { build_list :goods_nomenclature, 1, goods_nomenclature_sid: 1 }
    let(:grouped_goods_nomenclatures) { { 1 => goods_nomenclatures } }

    it { expect(wrapped).to all(be_a(described_class)) }
    it { expect(wrapped.first.goods_nomenclatures).to eq goods_nomenclatures }
  end
end
