module Admin
  class QueryAllCommodities
    def self.call(actual_date)
      # Splitting the queries this way makes the execution faster
      chapter_short_codes = Chapter.all.map(&:short_code)

      commodity_groups = chapter_short_codes.map do |chapter_code|
        Sequel::Model.db.fetch(
          'select * from public.fetch_chapter_commodities_for_date(?, ?) ' \
          'order by goods_nomenclature_item_id, producline_suffix',
          "#{chapter_code}%", actual_date
        )
      end

      # Running the queries and merging ...
      commodity_groups.flat_map(&:all)
    end
  end
end
