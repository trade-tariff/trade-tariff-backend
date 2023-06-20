module ChangesTablePopulator
  class CommodityCodeEndDated < Importer
    def source_table
      :goods_nomenclatures
    end

    def select_condition
      -> { [goods_nomenclature_item_id, goods_nomenclature_sid, producline_suffix] }
    end

    def where_condition
      previous_day = (day - 1.day)

      { validity_end_date: (previous_day.beginning_of_day..previous_day.end_of_day) }
    end

    def build_all_change_records(source_changes)
      source_changes.map do |source_change|
        last_valid_day = (day - 1.day).beginning_of_day
        declarable_on_last_day = end_line?(row: source_change, day: last_valid_day)

        build_change_record(row: source_change,
                            day:,
                            is_end_line: declarable_on_last_day)
      end
    end

    def change_type
      'commodity'
    end
  end
end
