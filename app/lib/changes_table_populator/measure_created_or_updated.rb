module ChangesTablePopulator
  class MeasureCreatedOrUpdated < Importer
    def source_table
      :measures
    end

    def select_condition
      -> { [goods_nomenclature_item_id, goods_nomenclature_sid] }
    end

    def where_condition
      Sequel.lit('validity_start_date <= ? AND ' \
                 '(validity_end_date IS NULL OR validity_end_date > ?) AND ' \
                 'operation IN (\'C\', \'U\') AND ' \
                 'operation_date = ?', day, day, day)
    end

    def build_all_change_records(source_changes)
      source_changes
        .uniq { |element| element[:goods_nomenclature_sid] }
        .collect_concat do |source_change|
          build_descendant_change_records(row: source_change, day:)
        end
    end

    def change_type
      'measure'
    end
  end
end
