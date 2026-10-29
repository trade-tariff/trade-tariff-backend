module Api
  module Admin
    module Csv
      class SearchReferenceSerializer
        include Api::Shared::CsvSerializer

        AI_GENERATED_LABEL_COLUMNS = %i[
          label_description
          label_synonyms
          label_colloquial_terms
          label_known_brands
          label_stale
          label_needs_review
          label_approved
          label_manually_edited
          label_expired
        ].freeze

        escape_formulas!

        column :id, column_name: 'Search reference ID'
        column :title, column_name: 'Title'
        column :goods_nomenclature_item_id, column_name: 'Commodity code'
        column :productline_suffix, column_name: 'Product line suffix'
        column :referenced_class, column_name: 'Referenced class' do |ref|
          ref[:referenced_class]
        end
        column :usage, column_name: 'Usage'
        column :label_description, column_name: 'Label description' do |ref|
          ref[:label_description]
        end
        column :label_synonyms, column_name: 'Label synonyms' do |ref|
          ref[:label_synonyms].to_a.join('; ')
        end
        column :label_colloquial_terms, column_name: 'Label colloquial terms' do |ref|
          ref[:label_colloquial_terms].to_a.join('; ')
        end
        column :label_known_brands, column_name: 'Label known brands' do |ref|
          ref[:label_known_brands].to_a.join('; ')
        end
        column :label_stale, column_name: 'Label stale' do |ref|
          ref[:label_stale]
        end
        column :label_needs_review, column_name: 'Label needs review' do |ref|
          ref[:label_needs_review]
        end
        column :label_approved, column_name: 'Label approved' do |ref|
          ref[:label_approved]
        end
        column :label_manually_edited, column_name: 'Label manually edited' do |ref|
          ref[:label_manually_edited]
        end
        column :label_expired, column_name: 'Label expired' do |ref|
          ref[:label_expired]
        end

        def column_options
          columns = self.class.column_options
          return columns if @options.fetch(:include_ai_labels, false)

          columns.reject { |column_option| AI_GENERATED_LABEL_COLUMNS.include?(column_option[:column]) }
        end
      end
    end
  end
end
