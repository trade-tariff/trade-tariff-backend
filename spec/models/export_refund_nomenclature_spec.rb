RSpec.describe ExportRefundNomenclature do
  describe '#additional_code' do
    let(:export_refund_nomenclature) { build :export_refund_nomenclature }

    it 'is a concatenation of additional code type and export refund code' do
      expect(
        export_refund_nomenclature.additional_code,
      ).to eq "#{export_refund_nomenclature.additional_code_type}#{export_refund_nomenclature.export_refund_code}"
    end
  end

  describe '#applicable?' do
    subject(:export_refund_nomenclature) { build :export_refund_nomenclature }

    it { is_expected.to be_applicable }
  end

  describe '#type' do
    subject(:export_refund_nomenclature) { build :export_refund_nomenclature }

    it 'returns a placeholder type for additional code consumers' do
      expect(export_refund_nomenclature.type).to eq('export_refund_nomenclature')
    end
  end
end
