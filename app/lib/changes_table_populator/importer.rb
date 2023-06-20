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

    def end_line?(row:, day: Time.zone.today)
      TimeMachine.at(day) do
        GoodsNomenclature.actual
                         .where(goods_nomenclature_sid: row[:goods_nomenclature_sid])
                         .first
                         .ns_declarable?
      end
    end

    def build_descendant_change_records(row:, day: Time.zone.today)
      find_source_and_children(row:, day:).map do |child|
        build_change_record(row: child, day:, is_end_line: child.ns_declarable?)
      end
    end

    def find_source_and_children(row:, day: Time.zone.today)
      gn = GoodsNomenclature
             .where(goods_nomenclature_sid: row[:goods_nomenclature_sid])
             .first

      last_valid_day = if gn.validity_end_date && gn.validity_end_date < day
                         gn.validity_end_date
                       else
                         day
                       end

      TimeMachine.at(last_valid_day) do
        [gn] + gn.ns_descendants
      end
    end
  end
end
