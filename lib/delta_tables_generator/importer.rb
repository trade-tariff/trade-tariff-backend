module DeltaTablesGenerator
  class Importer
    class << self
      DB = Sequel::Model.db

      def label
        'item'
      end

      def perform_import(day: Date.current) # rubocop:disable Lint/UnusedMethodArgument
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

      def where_condition(day: Date.current) # rubocop:disable Lint/UnusedMethodArgument
        raise NotImplementedError, 'Implement this method in the subclasses'
      end

      def integrate_element(row:, day: Date.current, is_end_line: nil, siblings: nil)
        [
          row[:goods_nomenclature_item_id],
          row[:goods_nomenclature_sid],
          row[:producline_suffix] || row[:productline_suffix] || '80',
          is_end_line || end_line?(row: row, day: day, siblings: siblings),
          delta_type,
          day,
        ]
      end

      def delta_type
        'commodity'
      end

      def end_line?(row:, day: Date.current, siblings: [])
        TimeMachine.at(day) do
          item_id = row[:goods_nomenclature_item_id]
          return false if chapter?(item_id) || heading?(item_id)

          suffix = row[:producline_suffix] || row[:productline_suffix]
          return false if suffix.present? && suffix != '80'

          children = if siblings&.any?
                       find_children_from_siblings(row: row, siblings: siblings)
                     else
                       find_children(row: row, day: day)
                     end
          children.none?
        end
      end

      def integrate_and_find_children(row:, day: Date.current)
        suffix = row[:producline_suffix] || row[:productline_suffix]
        children = find_children(row: row, day: day)
        is_end_line = suffix.nil? || suffix == '80' ? children.none? : false

        [integrate_element(row: row, day: day, is_end_line: is_end_line)]
          .concat(children.map { |child| integrate_element(row: child, day: day, siblings: children) })
      end

      def find_children_from_siblings(row:, siblings:)
        item_id = row[:goods_nomenclature_item_id]
        row_suffix = row[:producline_suffix] || row[:productline_suffix]

        if chapter?(item_id)
          children = siblings.select do |element|
            /^#{item_id[0, 2]}/ =~ element[:goods_nomenclature_item_id]
          end
        elsif heading?(item_id)
          children = siblings.select do |element|
            /^#{item_id[0, 4]}/ =~ element[:goods_nomenclature_item_id]
          end
        else
          goods_nomenclature = GoodsNomenclature.eager(:goods_nomenclature_indents)
                                                .first(goods_nomenclature_sid: row[:goods_nomenclature_sid])
          children = siblings.select do |element|
            suffix = element[:producline_suffix] || element[:productline_suffix]
            element[:number_indents] > goods_nomenclature.number_indents &&
              (element[:goods_nomenclature_item_id] > item_id ||
               (element[:goods_nomenclature_item_id] == item_id &&
                suffix > row_suffix))
          end
        end

        children
      end

      def find_children(row:, day: Date.current)
        TimeMachine.at(day) do
          item_id = row[:goods_nomenclature_item_id]

          if chapter?(item_id)
            return chapter_children(row: row, day: day)
          elsif heading?(item_id)
            return heading_children(row: row, day: day)
          else
            return commodity_children(row: row, day: day)
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

      def chapter_children(row:, day: Date.current)
        item_id = row[:goods_nomenclature_item_id]
        chapter_id_regex = "#{item_id[0, 2]}________"

        # using sequel DSL conflicts with Rubocop directives
        # rubocop:disable all
        DB[:goods_nomenclatures]
          .left_join(:goods_nomenclature_indents,
                     goods_nomenclatures__goods_nomenclature_sid: :goods_nomenclature_indents__goods_nomenclature_sid)
          .where {
            (goods_nomenclatures__validity_start_date <= day) &
            ((goods_nomenclatures__validity_end_date == nil) | (goods_nomenclatures__validity_end_date >= day)) &
            (like(goods_nomenclatures__goods_nomenclature_item_id, chapter_id_regex))
          }
          .distinct(:goods_nomenclatures__goods_nomenclature_sid)
          .select { |result_row|
            [
              result_row.goods_nomenclatures__goods_nomenclature_item_id,
              result_row.goods_nomenclatures__goods_nomenclature_sid,
              result_row.goods_nomenclatures__producline_suffix,
              result_row.number_indents
            ]
          }
          .all
        # rubocop:enable all
      end

      def heading_children(row:, day: Date.current)
        item_id = row[:goods_nomenclature_item_id]
        heading_id_regex = "#{item_id[0, 4]}______"

        # using sequel DSL conflicts with Rubocop directives
        # rubocop:disable all
        return DB[:goods_nomenclatures]
          .left_join(:goods_nomenclature_indents,
                     goods_nomenclatures__goods_nomenclature_sid: :goods_nomenclature_indents__goods_nomenclature_sid)
          .where {
            (goods_nomenclatures__validity_start_date <= day) &
            ((goods_nomenclatures__validity_end_date == nil) | (goods_nomenclatures__validity_end_date >= day)) &
            (like(goods_nomenclatures__goods_nomenclature_item_id, heading_id_regex))
          }
          .distinct(:goods_nomenclatures__goods_nomenclature_sid)
          .select { |result_row|
            [
              result_row.goods_nomenclatures__goods_nomenclature_item_id,
              result_row.goods_nomenclatures__goods_nomenclature_sid,
              result_row.goods_nomenclatures__producline_suffix,
              result_row.number_indents,
            ]
          }
          .all
        # rubocop:enable all
      end

      def commodity_children(row:, day: Date.current)
        item_id = row[:goods_nomenclature_item_id]
        heading_id_regex = "#{item_id[0, 4]}______"

        goods_nomenclature = GoodsNomenclature.eager(:goods_nomenclature_indents)
                                              .first(goods_nomenclature_sid: row[:goods_nomenclature_sid])
        productline_suffix = goods_nomenclature.producline_suffix
        indent = goods_nomenclature.goods_nomenclature_indent&.number_indents || 1

        # using sequel DSL conflicts with Rubocop directives
        # rubocop:disable all
        DB[:goods_nomenclatures]
          .left_join(:goods_nomenclature_indents,
                     goods_nomenclatures__goods_nomenclature_sid: :goods_nomenclature_indents__goods_nomenclature_sid)
          .where {
            (goods_nomenclatures__validity_start_date <= day) &
            ((goods_nomenclatures__validity_end_date =~ nil) |
             (goods_nomenclatures__validity_end_date >= day)) &
            (like(goods_nomenclatures__goods_nomenclature_item_id, heading_id_regex)) &
            ((goods_nomenclatures__goods_nomenclature_item_id > item_id) |
             ((goods_nomenclatures__goods_nomenclature_item_id == item_id) &
              (goods_nomenclatures__producline_suffix > productline_suffix))) &
            (number_indents > indent)
          }
          .distinct(:goods_nomenclatures__goods_nomenclature_sid)
          .select { |result_row|
            [
              result_row.goods_nomenclatures__goods_nomenclature_item_id,
              result_row.goods_nomenclatures__goods_nomenclature_sid,
              result_row.goods_nomenclatures__producline_suffix,
              result_row.number_indents,
            ]
          }
          .all
        # rubocop:enable all
      end
    end
  end
end
