RSpec.describe ExportRefundNomenclature do
  describe '#additional_code' do
    let(:export_refund_nomenclature) { build :export_refund_nomenclature }

    it 'is a concatenation of additional code type and export refund code' do
      expect(
        export_refund_nomenclature.additional_code,
      ).to eq "#{export_refund_nomenclature.additional_code_type}#{export_refund_nomenclature.export_refund_code}"
    end
  end
end
