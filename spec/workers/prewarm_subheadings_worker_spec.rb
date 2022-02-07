RSpec.describe PrewarmSubheadingsWorker, type: :worker do
  subject(:worker) { described_class.new }

  before do
    stub_const("#{described_class}::CACHE_CHILDREN_COUNT", 0)
    allow(CachedSubheadingService).to receive(:new).and_call_original
    allow(ExpensiveHeadingCommodityContextService).to receive(:new).and_call_original
    allow(Rails.cache).to receive(:fetch).and_call_original
  end

  context 'when there are no subheadings to populate' do
    it 'invokes the CachedCommodityService' do
      worker.perform

      expect(CachedSubheadingService).not_to have_received(:new)
    end

    it 'invokes the ExpensiveHeadingCommodityContextService' do
      worker.perform

      expect(ExpensiveHeadingCommodityContextService).to have_received(:new)
    end
  end

  context 'when there are subheadings to populate' do
    before do
      GoodsNomenclature.unrestrict_primary_key

      create(:chapter, :with_section, :with_indent, :with_guide, goods_nomenclature_sid: 1, indents: 0, producline_suffix: '80', goods_nomenclature_item_id: '0100000000')       # Live animals
      create(:heading, :with_indent, :with_description, goods_nomenclature_sid: 2, indents: 0, producline_suffix: '80', goods_nomenclature_item_id: '0101000000')   # Live horses, asses, mules and hinnies
      create(:commodity, :with_indent, :with_description, goods_nomenclature_sid: 3, indents: 1, producline_suffix: '10', goods_nomenclature_item_id: '0101210000') # Horses
      create(:commodity, :with_indent, :with_description, :with_overview_measures, goods_nomenclature_sid: 4, indents: 2, producline_suffix: '80', goods_nomenclature_item_id: '0101290000') # -- Other
      create(:commodity, :with_indent, :with_description, goods_nomenclature_sid: 5, indents: 3, producline_suffix: '80', goods_nomenclature_item_id: '0101291000') # ---- For slaughter
      create(:commodity, :with_indent, :with_description, goods_nomenclature_sid: 6, indents: 3, producline_suffix: '80', goods_nomenclature_item_id: '0101299000') # ---- Other
    end

    it 'invokes the CachedCommodityService' do
      worker.perform

      expect(CachedSubheadingService).to have_received(:new).with(an_instance_of(Subheading), Time.zone.today.iso8601).twice
    end

    it 'invokes the ExpensiveHeadingCommodityContextService' do
      worker.perform

      expect(ExpensiveHeadingCommodityContextService).to have_received(:new)
    end

    it 'caches the correct subheadings' do
      worker.perform

      today = Time.zone.today.iso8601

      expected_cache_keys = [
        "_subheading-3-#{today}", # Horses
        "_subheading-4-#{today}", # -- Other
      ]

      expected_cache_keys.each do |cache_key|
        expect(Rails.cache).to have_received(:fetch).with(cache_key, expires_in: 23.hours)
      end
    end
  end
end
