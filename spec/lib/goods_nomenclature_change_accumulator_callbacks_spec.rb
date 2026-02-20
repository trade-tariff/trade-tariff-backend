RSpec.describe GoodsNomenclatureChangeAccumulator do
  before { allow(described_class).to receive(:push!) }

  after { described_class.reset! }

  context 'when GoodsNomenclatureOrigin is created' do
    it 'pushes :moved' do
      create(:goods_nomenclature_origin,
             goods_nomenclature_item_id: '0102030000')

      expect(described_class).to have_received(:push!).with(
        hash_including(change_type: :moved, item_id: '0102030000'),
      )
    end
  end

  context 'when GoodsNomenclatureSuccessor is created' do
    it 'pushes :moved' do
      create(:goods_nomenclature_successor,
             goods_nomenclature_item_id: '0102030000')

      expect(described_class).to have_received(:push!).with(
        hash_including(change_type: :moved, item_id: '0102030000'),
      )
    end
  end

  context 'when GoodsNomenclature is created' do
    it 'pushes :structure_changed' do
      create(:goods_nomenclature,
             goods_nomenclature_item_id: '0102030000')

      expect(described_class).to have_received(:push!).with(
        hash_including(change_type: :structure_changed, item_id: '0102030000'),
      ).at_least(:once)
    end

    it 'does not push when not current' do
      create(:goods_nomenclature,
             goods_nomenclature_item_id: '0102030000',
             validity_start_date: 1.year.from_now)

      expect(described_class).not_to have_received(:push!)
    end
  end

  context 'when GoodsNomenclature is updated' do
    it 'pushes :structure_changed' do
      gn = create(:goods_nomenclature,
                  goods_nomenclature_item_id: '0102030000')

      gn.update(validity_end_date: Time.zone.today)

      expect(described_class).to have_received(:push!).with(
        hash_including(change_type: :structure_changed),
      ).at_least(:twice)
    end
  end

  context 'when GoodsNomenclatureIndent is created' do
    it 'pushes :structure_changed' do
      create(:goods_nomenclature_indent,
             goods_nomenclature_item_id: '0102030000')

      expect(described_class).to have_received(:push!).with(
        hash_including(change_type: :structure_changed, item_id: '0102030000'),
      )
    end

    it 'does not push when not current' do
      create(:goods_nomenclature_indent,
             goods_nomenclature_item_id: '0102030000',
             validity_start_date: 1.year.from_now)

      expect(described_class).not_to have_received(:push!)
    end
  end

  context 'when GoodsNomenclatureDescription is created' do
    it 'pushes :description_changed' do
      create(:goods_nomenclature_description,
             goods_nomenclature_item_id: '0102030000')

      expect(described_class).to have_received(:push!).with(
        hash_including(change_type: :description_changed, item_id: '0102030000'),
      )
    end

    it 'does not push when not current' do
      create(:goods_nomenclature_description,
             goods_nomenclature_item_id: '0102030000',
             validity_start_date: 1.year.from_now)

      expect(described_class).not_to have_received(:push!)
    end
  end
end
