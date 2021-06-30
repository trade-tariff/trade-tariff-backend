module DeltaTablesGenerator
  class Importer
    class << self
      DB = Sequel::Model.db

      def label
        'item'
      end

      def perform_import(day: Date.current)
        raise NotImplementedError, 'Implement this method in the subclasses'
      end

      def perform_backlog_import(from: Date.current - 3.months, to: Date.current)
        (from..to).each do |day|
          perform_import(day: day)
        end
      end

      def table
        :goods_nomenclatures
      end

      def import_fields
        %i[goods_nomenclature_item_id
           goods_nomenclature_sid
           productline_suffix
           end_line
           delta_type
           delta_date]
      end

      def where_condition(day: Date.current)
        'true'
      end

      def integrate_element(row:, day: Date.current, is_end_line: nil)
        [
          row[:goods_nomenclature_item_id],
          row[:goods_nomenclature_sid],
          row[:producline_suffix] || row[:productline_suffix] || '80',
          is_end_line || end_line?(row: row, day: day),
          delta_type,
          day,
        ]
      end

      def delta_type
        'commodity'
      end

      def end_line?(row:, day: Date.current)
        TimeMachine.at(day) do
          item_id = row[:goods_nomenclature_item_id]
          return false if chapter?(item_id) || heading?(item_id)

          suffix = row[:producline_suffix] || row[:productline_suffix]
          return false if suffix.present? && suffix != '80'

          find_children(row: row, day: day).none?
        end
      end

      def integrate_and_find_children(row:, day: Date.current)
        suffix = row[:producline_suffix] || row[:productline_suffix]
        children = find_children(row: row, day: day)
        is_end_line = suffix.nil? || suffix == '80' ? children.none? : false

        [integrate_element(row: row, day: day, is_end_line: is_end_line)]
          .concat(children.map { |child| integrate_element(row: child, day: day) })
      end

      def find_children(row:, day: Date.current)
        TimeMachine.at(day) do
          item_id = row[:goods_nomenclature_item_id]
          chapter_id = "#{item_id[0, 2]}________"
          heading_id = "#{item_id[0, 4]}______"

          if chapter?(item_id)
            return DB[:goods_nomenclatures]
              .where {
                (validity_start_date <= day) &
                ((validity_end_date == nil) | (validity_end_date >= day)) &
                (like(goods_nomenclature_item_id, chapter_id))
              }
              .all
          elsif heading?(item_id)
            return DB[:goods_nomenclatures]
              .where {
                (validity_start_date <= day) &
                ((validity_end_date == nil) | (validity_end_date >= day)) &
                (like(goods_nomenclature_item_id, heading_id))
              }
              .all
          else
            # or incomincian le dolenti note a farmisi sentire, or son venuta ove molto pianto mi percuote
            goods_nomenclature = GoodsNomenclature.first(goods_nomenclature_sid: row[:goods_nomenclature_sid])
            productline_suffix = goods_nomenclature.producline_suffix
            indent = goods_nomenclature.goods_nomenclature_indent&.number_indents

            DB[:goods_nomenclatures]
              .left_join(:goods_nomenclature_indents,
                         goods_nomenclatures__goods_nomenclature_sid: :goods_nomenclature_indents__goods_nomenclature_sid)
              .where {
                (goods_nomenclatures__validity_start_date <= day) &
                ((goods_nomenclatures__validity_end_date =~ nil) |
                 (goods_nomenclatures__validity_end_date >= day)) &
                (like(goods_nomenclatures__goods_nomenclature_item_id, heading_id)) &
                ((goods_nomenclatures__goods_nomenclature_item_id > item_id) |
                 ((goods_nomenclatures__goods_nomenclature_item_id == item_id) &
                  (goods_nomenclatures__producline_suffix > productline_suffix))) &
                (number_indents > indent)
              }
              .distinct(:goods_nomenclatures__goods_nomenclature_sid)
              .select { |row|
                [
                  row.goods_nomenclatures__goods_nomenclature_item_id,
                  row.goods_nomenclatures__goods_nomenclature_sid,
                  row.goods_nomenclatures__producline_suffix
                ]
              }
          end
        end
      end

      protected

      def chapter?(item_id)
        item_id.ends_with?('00000000')
      end

      def heading?(item_id)
        item_id.ends_with?('000000') && !chapter?(item_id)
      end
    end
  end
end
