module ChangesTablePopulator
  class CommodityCodeStarted < Importer
    def source_table
      :goods_nomenclatures
    end

    def select_condition
      -> { [goods_nomenclature_item_id, goods_nomenclature_sid, producline_suffix] }
    end

    def where_condition
      { validity_start_date: day }
    end

    def build_all_change_records(source_changes)
      source_changes.map do |source_change|
        build_change_record(row: source_change,
                            day:,
                            is_end_line: end_line?(row: source_change, day:))
      end
    end

    def change_type
      'commodity'
    end
  end
end
