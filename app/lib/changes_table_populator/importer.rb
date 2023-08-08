module ChangesTablePopulator
  class Importer
    IMPORT_FIELDS = %i[
      goods_nomenclature_item_id
      goods_nomenclature_sid
      productline_suffix
      end_line
      change_type
      change_date
    ].freeze
    DB = Sequel::Model.db

    attr_reader :day

    class << self
      delegate :populate, to: :new

      def populate_backlog(from: Time.zone.today - 3.months, to: Time.zone.today)
        from = from.to_date
        to = to.to_date
        (from..to).each do |day|
          new(day).populate
        end
      end
    end

    def initialize(day = Time.zone.today)
      @day = day
    end

    def populate
      change_records = build_all_change_records(source_dataset)

      DB[:changes]
        .insert_conflict(constraint: :changes_upsert_unique)
        .import(IMPORT_FIELDS, change_records)
    end

    def source_dataset
      DB[source_table]
        .where(where_condition)
        .select(&select_condition)
    end

    protected

    def source_table
      raise NotImplementedError, 'Implement this method in the subclasses'
    end

    def select_condition
      raise NotImplementedError, 'Implement this method in the subclasses'
    end

    def where_condition(day: Time.zone.today)
      raise NotImplementedError, 'Implement this method in the subclasses'
    end

    def change_type
      raise NotImplementedError, 'Implement this method in the subclasses'
    end

    def descendants_date(goods_nomenclature, day)
      if goods_nomenclature.validity_end_date && day > goods_nomenclature.validity_end_date
        goods_nomenclature.validity_end_date
      elsif day < goods_nomenclature.validity_start_date
        goods_nomenclature.validity_start_date
      else
        day
      end
    end

    def build_change_record(row:, is_end_line:, day: Time.zone.today)
      [
        row[:goods_nomenclature_item_id],
        row[:goods_nomenclature_sid],
        row[:producline_suffix] || row[:productline_suffix] || '80',
        is_end_line,
        change_type,
        day,
      ]
    end

    def build_all_change_records(source_changes)
      source_changes.map do |source_change|
        build_change_record(row: source_change,
                            day:,
                            is_end_line: end_line?(source_change, day))
      end
    end

    def end_line?(row, day)
      gn = GoodsNomenclature
             .where(goods_nomenclature_sid: row[:goods_nomenclature_sid])
             .first

      TimeMachine.at(descendants_date(gn, day)) do
        gn.declarable?
      end
    end

    def find_source_and_descendants(row:, day:)
      gn = GoodsNomenclature
             .where(goods_nomenclature_sid: row[:goods_nomenclature_sid])
             .first

      TimeMachine.at(descendants_date(gn, day)) do
        [gn] + gn.descendants
      end
    end
  end
end
