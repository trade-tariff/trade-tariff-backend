module Api
  module Admin
    module Csv
      class SearchReferenceChangeSerializer
        include Api::Shared::CsvSerializer

        # Titles and whodunnit values come from users, so make every text cell safe to open.
        escape_formulas!

        column :section_label, column_name: 'Operation'
        column :goods_nomenclature_item_id, column_name: 'Commodity code'
        column :productline_suffix, column_name: 'Product line suffix'
        column :title, column_name: 'Title'
        column :goods_nomenclature_url, column_name: 'Commodity URL'
        column :successor_ids, column_name: 'Successors' do |change|
          change.successor_ids.join(' ')
        end
        column :previous_goods_nomenclature_item_id, column_name: 'Previous commodity code'
        column :previous_title, column_name: 'Previous title'
        column :previous_usage, column_name: 'Previous usage'
        column :source, column_name: 'Source'
        column :changed_by, column_name: 'Changed by'
        column :changed_at, column_name: 'Changed at' do |change|
          change.changed_at&.iso8601
        end
        column :search_reference_id, column_name: 'Search reference ID'
      end
    end
  end
end
