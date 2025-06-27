RSpec.describe GoodsNomenclatures::TreeNodeOverride do
  describe 'attributes' do
    it { is_expected.to respond_to :goods_nomenclature_indent_sid }
    it { is_expected.to respond_to :depth }
    it { is_expected.to respond_to :created_at }
    it { is_expected.to respond_to :updated_at }
  end

  describe 'validations' do
    subject { described_class.new.tap(&:valid?).errors }

    it { is_expected.to include goods_nomenclature_indent_sid: ['is not present'] }
    it { is_expected.to include depth: ['is not present'] }
    it { is_expected.to include created_at: ['is not present'] }
  end
end
