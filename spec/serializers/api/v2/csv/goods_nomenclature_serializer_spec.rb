RSpec.describe Api::V2::Csv::GoodsNomenclatureSerializer do
  describe '#serializable_csv' do
    subject(:rows) { serialized.lines.map(&:strip) }

    let(:serialized) { described_class.new(serializable).serialized_csv }
    let(:serializable) { [goods_nomenclature] }
    let(:goods_nomenclature) { create(:heading, :with_description) }

    it { is_expected.to have_attributes length: 2 }

    it 'serializes heading correctly' do
      expect(rows[0].split(',')).to eq(
        [
          'SID',
          'Goods Nomenclature Item ID',
          'Indents',
          'Description',
          'Product Line Suffix',
          'Href',
          'Formatted description',
          'Start date',
          'End date',
          'Declarable',
          'Parent SID',
        ],
      )
    end

    it 'serializes row correctly' do
      expect(rows[1].split(',', -1)).to eq(
        [
          goods_nomenclature.goods_nomenclature_sid.to_s,
          goods_nomenclature.goods_nomenclature_item_id,
          '0',
          goods_nomenclature.description,
          '80',
          "/uk/api/headings/#{goods_nomenclature.short_code}",
          goods_nomenclature.formatted_description,
          "#{goods_nomenclature.validity_start_date.to_date} 00:00:00 UTC",
          '',
          'true',
          '',
        ],
      )
    end

    context 'with subheading' do
      let(:goods_nomenclature) { create :commodity, :with_children }

      it { expect(rows[1]).to match "/uk/api/subheadings/#{goods_nomenclature.to_param}" }
    end

    context 'with parent' do
      let(:goods_nomenclature) { create :commodity, :with_heading }

      it 'includes the parent sid' do
        expect(rows[1].split(',')[10]).to eq \
          goods_nomenclature.heading.goods_nomenclature_sid.to_s
      end
    end
  end
end
