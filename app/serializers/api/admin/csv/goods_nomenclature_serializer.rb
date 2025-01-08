module Api
  module Admin
    module Csv
      class GoodsNomenclatureSerializer
        include Api::Shared::CsvSerializer

        column :goods_nomenclature_sid, column_name: 'SID'
        column :goods_nomenclature_item_id, column_name: 'Commodity code'
        column :producline_suffix, column_name: 'Product line suffix'
        column :csv_formatted_description, column_name: 'Description'
        column :validity_start_date, column_name: 'Start date'
        column :validity_end_date, column_name: 'End date'
        column :number_indents, column_name: 'Indentation'
        column :end_line, column_name: 'End line', &:declarable?
        column :goods_nomenclature_class, column_name: 'Class'

        column :item_id_plus_pls, column_name: 'ItemIDPlusPLS' do |goods_nomenclature|
          "#{goods_nomenclature.goods_nomenclature_item_id}_#{goods_nomenclature.producline_suffix}"
        end

        column :ancestors, column_name: 'Hierarchy' do |goods_nomenclature|
          ancestor_ids = goods_nomenclature.ancestors.map do |ancestor|
            "#{ancestor.goods_nomenclature_item_id}_#{ancestor.producline_suffix}"
          end

          ancestor_ids.join(' ')
        end
      end
    end
  end
end
