module Reporting
  class Differences
    class Loaders
      class Endline
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

          return nil if matching_uk_goods_nomenclature['End line'] == matching_xi_goods_nomenclature['End line']

          item_id, pls = matching_uk_goods_nomenclature['ItemIDPlusPLS'].split('_')
          uk_endline_status = matching_uk_goods_nomenclature['End line'] == 'true' ? '1' : '0'
          eu_endline_status = matching_xi_goods_nomenclature['End line'] == 'true' ? '1' : '0'

          [
            "#{item_id} (#{pls})",
            uk_endline_status,
            eu_endline_status,
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
