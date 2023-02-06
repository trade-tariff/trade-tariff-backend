namespace :search_references do
  desc 'Populate search references with goods nomenclature item id and sid'
  task populate: :environment do
    TimeMachine.now do
      SearchReference.each do |search_reference|
        referenced_goods_nomenclature = search_reference.referenced_dataset.actual.take

        search_reference.goods_nomenclature_item_id = referenced_goods_nomenclature.goods_nomenclature_item_id
        search_reference.goods_nomenclature_sid = referenced_goods_nomenclature.goods_nomenclature_sid
        search_reference.save
      end
    end
  end
end
