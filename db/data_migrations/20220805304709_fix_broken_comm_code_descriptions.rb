Sequel.migration do
  up do
    tunas = GoodsNomenclatureDescription.where(goods_nomenclature_description_period_sid: 154_585)
    if tunas.present?
      tunas.update(description: 'Tunas (of the genus Thunnus), skipjack tuna (stripe-bellied bonito) (Katsuwonus pelamis), excluding edible fish offal of subheadings 0302 91 to 0302 99')
    end
    engines = GoodsNomenclatureDescription.where(goods_nomenclature_description_period_sid: 157_423)
    if engines.present?
      engines.update(description: 'Four-stroke petrol engines of a cylinder capacity of not more than 250 cm3 for use in the manufacture of garden equipment of heading 8432, 8433, 8436 or 8508')
    end
  end

  down {}
end
