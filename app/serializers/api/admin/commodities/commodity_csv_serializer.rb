require_relative '../../../concerns/api/v2/csv/csv_serializer'

module Api
  module Admin
    module Commodities
      class CommodityCsvSerializer
        include Api::V2::Csv::CsvSerializer

        column :goods_nomenclature_sid, column_name: 'SID' do |row|
          row[:goods_nomenclature_sid]
        end

        column :code, column_name: 'Commodity code' do |row|
          row[:goods_nomenclature_item_id]
        end

        column :producline_suffix, column_name: 'Product line suffix' do |row|
          row[:producline_suffix]
        end

        column :description, column_name: 'Description' do |row|
          row[:description]
        end

        column :validity_start_date, column_name: 'Start date' do |row|
          row[:validity_start_date]
        end

        column :validity_end_date, column_name: 'End date' do |row|
          row[:validity_end_date]
        end

        column :number_indents, column_name: 'Indentation' do |row|
          row[:number_indents]
        end

        column :end_line, column_name: 'End line' do |row|
          end_line = row[:leaf] == '1' && row[:producline_suffix] == '80'

          end_line ? 1 : 0
        end

        column :item_id_plus_pls, column_name: 'ItemIDPlusPLS' do |row|
          "#{row[:goods_nomenclature_item_id]}_#{row[:producline_suffix]}"
        end

        # TODO: calculate the hierarchy
        # column :hierarchy, column_name: 'Hierarchy' do |row|
        #   'hierarchy'
        # end
      end
    end
  end
end
