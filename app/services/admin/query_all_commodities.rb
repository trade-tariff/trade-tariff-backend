module Admin
  class QueryAllCommodities
    def self.call(actual_date)
      commodity_groups = []

      # Splitting the queries this way make the execution faster
      (0..9).each do |starting_digit|
        commodity_groups << Sequel::Model.db.fetch(
          'select * from public.goods_nomenclature_export_new(?, ?) order by 2, 3',
          "#{starting_digit}%", actual_date
        )
      end

      # Running the queries and merging ...
      commodity_groups.flat_map(&:all)
    end
  end
end
