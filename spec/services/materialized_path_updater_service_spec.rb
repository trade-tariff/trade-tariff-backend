RSpec.describe MaterializedPathUpdaterService do
  subject(:service) { described_class.new(chapter) }

  context 'when passed a chapter with nested goods nomenclatures' do
    let(:chapter) { Chapter.by_code('02').take }

    before do
      # Full tree
      create(:chapter,   :with_indent, goods_nomenclature_sid: 10_000, indents: 0, producline_suffix: '80', goods_nomenclature_item_id: '0200000000') # Live animals
      create(:heading,   :with_indent, goods_nomenclature_sid: 20_000, indents: 0, producline_suffix: '80', goods_nomenclature_item_id: '0201000000') # Live horses, asses, mules and hinnies
      create(:commodity, :with_indent, goods_nomenclature_sid: 30_000, indents: 1, producline_suffix: '10', goods_nomenclature_item_id: '0201210000') # Horses < target subheading
      create(:commodity, :with_indent, goods_nomenclature_sid: 40_000, indents: 2, producline_suffix: '80', goods_nomenclature_item_id: '0201210000') # -- Pure-bred breeding animals
      create(:commodity, :with_indent, goods_nomenclature_sid: 50_000, indents: 2, producline_suffix: '80', goods_nomenclature_item_id: '0201290000') # -- Other
      create(:commodity, :with_indent, goods_nomenclature_sid: 60_000, indents: 3, producline_suffix: '80', goods_nomenclature_item_id: '0201291000') # ---- For slaughter
      create(:commodity, :with_indent, goods_nomenclature_sid: 70_000, indents: 3, producline_suffix: '80', goods_nomenclature_item_id: '0201299000') # ---- Other
      create(:commodity, :with_indent, goods_nomenclature_sid: 80_000, indents: 1, producline_suffix: '80', goods_nomenclature_item_id: '0201300000') # Asses
      create(:commodity, :with_indent, goods_nomenclature_sid: 90_000, indents: 1, producline_suffix: '80', goods_nomenclature_item_id: '0201900000') # Other
    end

    it 'generates the paths correctly' do
      service.call

      actual_paths = [chapter.path.to_a] + chapter.goods_nomenclatures.pluck(:path).map(&:to_a)

      expected_paths = [
        [],
        [10_000],
        [10_000, 20_000],
        [10_000, 20_000, 30_000],
        [10_000, 20_000, 30_000],
        [10_000, 20_000, 30_000, 50_000],
        [10_000, 20_000, 30_000, 50_000],
        [10_000, 20_000],
        [10_000, 20_000],
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
