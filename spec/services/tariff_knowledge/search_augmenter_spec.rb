RSpec.describe TariffKnowledge::SearchAugmenter do
  describe '.call' do
    subject(:augment) { described_class.call(results) }

    let(:results) do
      [
        GoodsNomenclatureResult.new(
          id: declarable.goods_nomenclature_sid,
          goods_nomenclature_item_id: declarable.goods_nomenclature_item_id,
          goods_nomenclature_sid: declarable.goods_nomenclature_sid,
          producline_suffix: declarable.producline_suffix,
          goods_nomenclature_class: declarable.goods_nomenclature_class,
          description: 'Live horses',
          formatted_description: 'Live horses',
          self_text: 'Live horses',
          classification_description: 'Live horses',
          full_description: 'Live horses',
          heading_description: 'Live animals',
          declarable: true,
          score: 1.0,
          confidence: nil,
        ),
      ]
    end
    let(:declarable) { create(:commodity, goods_nomenclature_item_id: '0101210000') }

    before do
      TariffKnowledge::DeclarableContext.create(
        goods_nomenclature_sid: declarable.goods_nomenclature_sid,
        goods_nomenclature_item_id: declarable.goods_nomenclature_item_id,
        content: 'Chapter 01 note 1: excludes fish of heading 0301.',
        context_hash: Digest::SHA256.hexdigest('context'),
        generated_at: Time.zone.now,
      )
    end

    it 'appends context to descriptions' do
      result = augment.first

      expect(result.full_description).to include('Live horses')
      expect(result.full_description).to include('Tariff note context')
      expect(result.full_description).to include('excludes fish')
    end
  end
end
