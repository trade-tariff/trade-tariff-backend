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
          puts "Hello, importing #{label} for #{day}" # replace with better logging
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
          is_end_line || end_line(row: row, day: day),
          delta_type,
          day,
        ]
      end

      def integrate_children(children:, day: Date.current)
        return [] if children.empty?

        children.map do |commodity|
          is_end_line = commodity.producline_suffix != '80' || commodity.children.none?
          integrate_element(row: commodity, day: day, is_end_line: is_end_line)
        end
      end

      def delta_type
        'commodity'
      end

      def end_line(row:, day: Date.current)
        TimeMachine.at(day) do
          suffix = row[:producline_suffix] || row[:productline_suffix]
          if suffix.nil? || suffix == '80'
            goods_nomenclature = GoodsNomenclature.first(goods_nomenclature_sid: row[:goods_nomenclature_sid])

            if goods_nomenclature &&
                GoodsNomenclature.class_determinator.call(goods_nomenclature) == 'Commodity'
              commodity = Commodity.first(goods_nomenclature_sid: row[:goods_nomenclature_sid])
              return true unless commodity.heading

              return commodity&.children&.none? ? true : false
            end
          end
        end

        false
      end

      def integrate_and_find_children(row:, day: Date.current)
        suffix = row[:producline_suffix] || row[:productline_suffix]
        children = find_children(row, day)
        [[
          row[:goods_nomenclature_item_id],
          row[:goods_nomenclature_sid],
          suffix || '80',
          suffix.nil? || suffix == '80' ? children.none? : true,
          delta_type,
          day,
        ]].concat(children)
      end

      def find_children(row, day)
        TimeMachine.at(day) do
          goods_nomenclature = GoodsNomenclature.first(goods_nomenclature_sid: row[:goods_nomenclature_sid])

          if goods_nomenclature
            case GoodsNomenclature.class_determinator.call(goods_nomenclature)
            when 'Commodity'
              commodity = Commodity.first(goods_nomenclature_sid: row[:goods_nomenclature_sid])
              return [] unless commodity&.heading

              return integrate_children(children: commodity.children, day: day)
            when 'Heading'
              heading = Heading.first(goods_nomenclature_sid: row[:goods_nomenclature_sid])
              commodities = heading.commodities
              return commodities
                .map { |commodity| integrate_element(row: commodity, day: day) }
                .concat(integrate_children(children: commodities.map(&:children).flatten, day: day))
            when 'Chapter'
              chapter = Chapter.first(goods_nomenclature_sid: row[:goods_nomenclature_sid])
              headings = chapter.headings
              commodities = headings.map(&:commodities).flatten
              return headings
                .map { |heading| integrate_element(row: heading, day: day) }
                .concat(commodities.map { |commodity| integrate_element(row: commodity, day: day) })
                .concat(integrate_children(children: commodities.map(&:children).flatten, day: day))
            end
          end
        end

        []
      end
    end
  end
end
