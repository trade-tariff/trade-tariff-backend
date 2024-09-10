module Reporting
  class Differences
    class Loaders
      class GoodsNomenclatureEndDate
        include Reporting::Differences::Loaders::Helpers

        def data
          matching_goods_nomenclature = uk_goods_nomenclature_ids.keys & xi_goods_nomenclature_ids.keys

          matching_goods_nomenclature.each_with_object([]) do |matching, acc|
            row = build_row_for(matching)
            acc << row unless row.nil?
          end
        end

        def build_row_for(matching)
          matching_uk_goods_nomenclature = uk_goods_nomenclature_ids[matching]
          matching_xi_goods_nomenclature = xi_goods_nomenclature_ids[matching]

          uk_start_date = matching_uk_goods_nomenclature['End date']&.to_date&.strftime('%d/%m/%Y')
          eu_start_date = matching_xi_goods_nomenclature['End date']&.to_date&.strftime('%d/%m/%Y')

          return nil if uk_start_date == eu_start_date

          item_id, pls = matching_uk_goods_nomenclature['ItemIDPlusPLS'].split('_')

          [
            "#{item_id} (#{pls})",
            uk_start_date,
            eu_start_date,
          ]
        end

        def uk_goods_nomenclature_ids
          @uk_goods_nomenclature_ids ||= uk_goods_nomenclatures.index_by do |goods_nomenclature|
            goods_nomenclature['ItemIDPlusPLS']
          end
        end

        def xi_goods_nomenclature_ids
          @xi_goods_nomenclature_ids ||= xi_goods_nomenclatures.index_by do |goods_nomenclature|
            goods_nomenclature['ItemIDPlusPLS']
          end
        end
      end
    end
  end
end
