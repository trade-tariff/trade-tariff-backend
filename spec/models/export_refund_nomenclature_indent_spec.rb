RSpec.describe ExportRefundNomenclatureIndent do
  subject(:export_refund_nomenclature_indent) { erni.number_indents }

  let(:erni) { build :export_refund_nomenclature_indent }

  describe '#number_indents' do
    it 'is an alias for number_export_refund_nomenclature_indents' do
      expect(export_refund_nomenclature_indent).to eq erni.number_export_refund_nomenclature_indents
    end
  end
end
