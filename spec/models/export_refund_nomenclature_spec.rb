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

  describe 'coverage' do
    subject(:export_refund_nomenclature) do
      create(:export_refund_nomenclature, goods_nomenclature_item_id: '1234567890')
    end

    let(:relation) { object_double(described_class.dataset) }

    before do
      create(
        :export_refund_nomenclature_description,
        export_refund_nomenclature_sid: export_refund_nomenclature.export_refund_nomenclature_sid,
        description: 'Export refund description',
      )
      create(
        :export_refund_nomenclature_indent,
        export_refund_nomenclature_sid: export_refund_nomenclature.export_refund_nomenclature_sid,
        number_export_refund_nomenclature_indents: 1,
      )

      allow(described_class).to receive(:select).and_return(relation)
      allow(relation).to receive_messages(
        eager: relation,
        join_table: relation,
        order: relation,
        all: [],
      )
    end

    it 'covers helper methods' do
      expect(export_refund_nomenclature).to have_attributes(
        description: 'Export refund description',
        number_indents: 1,
        uptree: [export_refund_nomenclature],
        additional_code_sid: export_refund_nomenclature.export_refund_nomenclature_sid,
        code: export_refund_nomenclature.additional_code,
        formatted_description: '',
        heading_id: '1234______',
      )
    end
  end
end
