Sequel.migration do

    up do
        Sequel::Model.db[:goods_nomenclature_descriptions_oplog].where(id: 154585).update(description: 'Tunas (of the genus Thunnus), skipjack tuna (stripe-bellied bonito) (Katsuwonus pelamis), excluding edible fish offal of subheadings 0302 91 to 0302 99')
        Sequel::Model.db[:goods_nomenclature_descriptions_oplog].where(id: 157423).update(description: 'Four-stroke petrol engines of a cylinder capacity of not more than 250 cm3 for use in the manufacture of garden equipment of heading 8432, 8433, 8436 or 8508')
    end

    down {}
end
