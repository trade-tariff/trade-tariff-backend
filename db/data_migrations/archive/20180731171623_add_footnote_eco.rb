TradeTariffBackend::DataMigrator.migration do
  name "Assign footnote_id/footnote_type_id 002 05 ECO to list of heading ids and their commodities"

  up do
    applicable { false }
    # The apply block is idempotent
    apply {
      footnote = Footnote.where(footnote_id: "002", footnote_type_id: "05").first

      codes = [ "28111100", "28121200", "28121300", "28121400", "28121500", "28121600",
          "28121700", "28121990", "28139010", "28261910", "28261990", "28269080",
          "28301000", "28371100", "28371900", "28372000", "29051900", "29055998",
          "29141990", "29181700", "29181998", "29201900", "29202100", "29202200",
          "29202300", "29202400", "29202900", "29211100", "29211400", "29211950",
          "29211999", "29221500", "29221700", "29221800", "29221900", "29299000",
          "29307000", "29309098", "29313100", "29313300", "29313920", "29313930",
          "29313990", "29333999", "3601", "3602", "3603", "39269097", "63079098",
          "65061010", "65061080", "72299090", "7504", "7603", "810390", "810990",
          "840110", "840140", "8411", "8412", "8413", "8414", "841989", "842119",
          "842230", "8458", "8459", "846011", "846021", "847989", "8481", "850440",
          "851410", "851420", "851430", "852580", "8526", "85285900", "8532",
          "853530", "85402080", "854081", "854089", "854320", "854370", "8702",
          "87059080", "87089997", "8710", "8802", "890610", "900580", "901320",
          "901420", "9015", "902219", "902620", "902780", "903110", "903180", "93" ]

      codes.each do |code|
        Sequel::Model.db.fetch("SELECT goods_nomenclature_item_id FROM measures_oplog
                                WHERE goods_nomenclature_item_id LIKE '#{code}%'
                                GROUP BY goods_nomenclature_item_id").all do |measure|
          puts "Running code #{code} and Measure with gono_item_id #{measure[:goods_nomenclature_item_id]}"
          goods_nomenclature = GoodsNomenclature.where(goods_nomenclature_item_id: measure[:goods_nomenclature_item_id]).first

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
    }
  end

  down do
    applicable { false }
    apply { } # noop
  end
end
