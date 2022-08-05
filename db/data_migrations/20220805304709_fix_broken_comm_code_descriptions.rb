Sequel.migration do
  up do
    tunas = GoodsNomenclatureDescription.where(goods_nomenclature_description_period_sid: 154_585)
    tunas.update(description: 'Tunas (of the genus Thunnus), skipjack tuna (stripe-bellied bonito) (Katsuwonus pelamis), excluding edible fish offal of subheadings 0302 91 to 0302 99')
    engines = GoodsNomenclatureDescription.where(goods_nomenclature_description_period_sid: 157_423)
    engines.update(description: 'Four-stroke petrol engines of a cylinder capacity of not more than 250 cm3 for use in the manufacture of garden equipment of heading 8432, 8433, 8436 or 8508')
  end

  down {}
end
