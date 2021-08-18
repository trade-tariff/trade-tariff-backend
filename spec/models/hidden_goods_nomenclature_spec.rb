describe HiddenGoodsNomenclature do
  it 'validates presence of goods_nomenclature_item_id' do
    hidden_goods_nomenclature = build :hidden_goods_nomenclature, goods_nomenclature_item_id: nil
    expect(hidden_goods_nomenclature).not_to be_valid
  end

  describe '.codes' do
    it 'returns array of hidden codes' do
      hidden_gono1 = create :hidden_goods_nomenclature, goods_nomenclature_item_id: '9900000000'
      hidden_gono2 = create :hidden_goods_nomenclature, goods_nomenclature_item_id: '0101000000'

      expect(described_class.codes).to eq [hidden_gono2.goods_nomenclature_item_id,
                                           hidden_gono1.goods_nomenclature_item_id]
    end
  end
end
