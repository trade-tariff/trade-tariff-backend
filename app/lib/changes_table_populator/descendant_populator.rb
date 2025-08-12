module ChangesTablePopulator
  module DescendantPopulator
    def build_all_change_records(source_changes)
      source_changes
        .reject { |element| element[:goods_nomenclature_sid].nil? }
        .uniq { |element| element[:goods_nomenclature_sid] }
        .collect_concat do |source_change|
          build_descendant_change_records(row: source_change, day:)
        end
    end

    def build_descendant_change_records(row:, day: Time.zone.today)
      find_source_and_descendants(row:, day:).map do |descendant|
        build_change_record(row: descendant, day:, is_end_line: descendant.declarable?)
      end
    end
  end
end
