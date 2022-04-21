TradeTariffBackend::DataMigrator.migration do
  name "Assign footnote to commodities"

  up do
    applicable { false }
    apply {
      TimeMachine.at("2020-10-08") do
        footnote = Footnote.where(footnote_id: "853", footnote_type_id: "05").first

        codes = %w[2103909081 2103909089]

        codes.each do |code|
          Sequel::Model.db.fetch("SELECT goods_nomenclature_item_id FROM measures_oplog
                                WHERE goods_nomenclature_item_id LIKE '#{code}%'
                                GROUP BY goods_nomenclature_item_id").all do |measure|
            puts "Running code #{code} and Measure with gono_item_id #{measure[:goods_nomenclature_item_id]}"

            goods_nomenclature = GoodsNomenclature.actual.declarable.where(
              goods_nomenclature_item_id: measure[:goods_nomenclature_item_id]
            ).first

            if goods_nomenclature.nil?
              puts "GoodsNomenclature #{measure.inspect} does not exist"
              next
            end

            if goods_nomenclature.footnotes_dataset.where(footnotes__footnote_id: footnote.footnote_id,
                                                          footnotes__footnote_type_id: footnote.footnote_type_id).empty?
              puts "Creating association for Footnote #{footnote.inspect} and GoodsNomenclature #{goods_nomenclature.inspect}"
              FootnoteAssociationGoodsNomenclature.associate_footnote_with_goods_nomenclature(goods_nomenclature, footnote)
            else
              puts "Footnote is already associated with GoodsNomenclature #{measure.inspect}"
            end
          end
        end
      end
    }
  end

  down do
    applicable { false }
    apply {} # noop
  end
end
