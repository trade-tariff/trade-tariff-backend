module ChangesTablePopulator
  class Importer
    class << self
      IMPORT_FIELDS = %i[
        goods_nomenclature_item_id
        goods_nomenclature_sid
        productline_suffix
        end_line
        change_type
        change_date
      ].freeze
      DB = Sequel::Model.db

      def populate(day: Time.zone.today)
        elements = DB[source_table]
          .where(where_condition(day:))
          .select(&select_condition)

        DB[:changes]
          .insert_conflict(constraint: :changes_upsert_unique)
          .import IMPORT_FIELDS, import_records(elements:, day:)
      end

      def populate_backlog(from: Time.zone.today - 3.months, to: Time.zone.today)
        from = from.to_date
        to = to.to_date
        (from..to).each do |day|
          populate(day:)
        end
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

      def integrate_and_find_children(row:, day: Time.zone.today)
        find_children(row:, day:).map do |child|
          build_change_record(row: child, day:, is_end_line: child.ns_declarable?)
        end
      end

      def find_children(row:, day: Time.zone.today)
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
end
