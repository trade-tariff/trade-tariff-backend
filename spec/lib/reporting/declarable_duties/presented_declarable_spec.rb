RSpec.describe Reporting::DeclarableDuties::PresentedDeclarable do
  subject(:presented_declarable) { described_class.new(commodity) }

  let(:commodity) { create(:commodity, :with_description, description: 'Horses') }

  describe '#commodity__sid' do
    it { expect(presented_declarable.commodity__sid).to eq commodity.goods_nomenclature_sid }
  end

  describe '#commodity__code' do
    it { expect(presented_declarable.commodity__code).to eq commodity.goods_nomenclature_item_id }
  end

  describe '#commodity__indent' do
    it { expect(presented_declarable.commodity__indent).to eq commodity.number_indents }
  end

  describe '#commodity__description' do
    it { expect(presented_declarable.commodity__description).to eq 'Horses' }
  end
end
