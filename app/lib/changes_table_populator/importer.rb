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
          .select &select_condition

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

      def source_table
        raise NotImplementedError, 'Implement this method in the subclasses'
      end

      def select_condition
        raise NotImplementedError, 'Implement this method in the subclasses'
      end

      def where_condition(day: Time.zone.today) # rubocop:disable Lint/UnusedMethodArgument
        raise NotImplementedError, 'Implement this method in the subclasses'
      end

      def change_type
        raise NotImplementedError, 'Implement this method in the subclasses'
      end

      def integrate_element(row:, day: Time.zone.today, is_end_line: nil, siblings: nil)
        [
          row[:goods_nomenclature_item_id],
          row[:goods_nomenclature_sid],
          row[:producline_suffix] || row[:productline_suffix] || '80',
          is_end_line || end_line?(row:, day:, siblings:),
          change_type,
          day,
        ]
      end

      def end_line?(row:, day: Time.zone.today, siblings: [])
        TimeMachine.at(day) do
          item_id = row[:goods_nomenclature_item_id]
          return false if chapter?(item_id) || heading?(item_id)

          suffix = row[:producline_suffix] || row[:productline_suffix]
          return false if suffix.present? && suffix != '80'

          children = if siblings&.any?
                       find_children_from_siblings(row:, siblings:)
                     else
                       find_children(row:, day:)
                     end
          children.none?
        end
      end

      def integrate_and_find_children(row:, day: Time.zone.today)
        suffix = row[:producline_suffix] || row[:productline_suffix]
        children = find_children(row:, day:)
        is_end_line = suffix.nil? || suffix == '80' ? children.none? : false

        [integrate_element(row:, day:, is_end_line:)]
          .concat(children.map { |child| integrate_element(row: child, day:, siblings: children) })
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

      def find_children(row:, day: Time.zone.today)
        TimeMachine.at(day) do
          item_id = row[:goods_nomenclature_item_id]

          if chapter?(item_id)
            return chapter_children(row:, day:)
          elsif heading?(item_id)
            return heading_children(row:, day:)
          else
            return commodity_children(row:, day:)
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

      def chapter_children(row:, day: Time.zone.today)
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

      def heading_children(row:, day: Time.zone.today)
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

      def commodity_children(row:, day: Time.zone.today)
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
