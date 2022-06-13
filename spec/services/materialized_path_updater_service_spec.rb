RSpec.describe MaterializedPathUpdaterService do
  subject(:service) { described_class.new(chapter) }

  context 'when passed a chapter with nested goods nomenclatures' do
    let(:chapter) { Chapter.by_code('01').take }

    before do
      # Full tree
      create(:chapter,   :with_indent, goods_nomenclature_sid: 1, indents: 0, producline_suffix: '80', goods_nomenclature_item_id: '0100000000') # Live animals
      create(:heading,   :with_indent, goods_nomenclature_sid: 2, indents: 0, producline_suffix: '80', goods_nomenclature_item_id: '0101000000') # Live horses, asses, mules and hinnies
      create(:commodity, :with_indent, goods_nomenclature_sid: 3, indents: 1, producline_suffix: '10', goods_nomenclature_item_id: '0101210000') # Horses < target subheading
      create(:commodity, :with_indent, goods_nomenclature_sid: 4, indents: 2, producline_suffix: '80', goods_nomenclature_item_id: '0101210000') # -- Pure-bred breeding animals
      create(:commodity, :with_indent, goods_nomenclature_sid: 5, indents: 2, producline_suffix: '80', goods_nomenclature_item_id: '0101290000') # -- Other
      create(:commodity, :with_indent, goods_nomenclature_sid: 6, indents: 3, producline_suffix: '80', goods_nomenclature_item_id: '0101291000') # ---- For slaughter
      create(:commodity, :with_indent, goods_nomenclature_sid: 7, indents: 3, producline_suffix: '80', goods_nomenclature_item_id: '0101299000') # ---- Other
      create(:commodity, :with_indent, goods_nomenclature_sid: 8, indents: 1, producline_suffix: '80', goods_nomenclature_item_id: '0101300000') # Asses
      create(:commodity, :with_indent, goods_nomenclature_sid: 9, indents: 1, producline_suffix: '80', goods_nomenclature_item_id: '0101900000') # Other
    end

    it 'generates the paths correctly' do
      service.call

      actual_paths = GoodsNomenclature.pluck(:path).map(&:to_a)

      expected_paths = [
        [],
        [1],
        [1, 2],
        [1, 2, 3],
        [1, 2, 3],
        [1, 2, 3, 5],
        [1, 2, 3, 5],
        [1, 2],
        [1, 2],
      ]

      expect(actual_paths).to eq(expected_paths)
    end
  end

  context 'when passed a chapter with no goods nomenclatures' do
    let(:chapter) { create(:chapter) }

    let(:change_goods_nomenclatures_with_paths) do
      change { GoodsNomenclature.exclude(path: Sequel.pg_array([], :integer)).count }
    end

    before { chapter }

    it { expect { service.call }.not_to change_goods_nomenclatures_with_paths }
  end
end
