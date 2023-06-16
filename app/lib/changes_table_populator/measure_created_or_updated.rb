module ChangesTablePopulator
  class MeasureCreatedOrUpdated < Importer
    include DescendantPopulator

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

    def change_type
      'measure'
    end
  end
end
