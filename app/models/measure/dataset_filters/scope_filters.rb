class Measure
  module DatasetFilters
    module ScopeFilters
      def with_measure_type(condition_measure_type)
        where(measures__measure_type_id: condition_measure_type.to_s)
      end

      def valid_to(last_effective_timestamp)
        where('measures.validity_start_date <= ?', last_effective_timestamp)
      end

      def terminated
        where('measures.validity_end_date IS NOT NULL')
      end

      def with_geographical_area(area)
        where(geographical_area_id: area)
      end

      def effective_start_date_column
        Sequel.function(:coalesce,
                        :measures__validity_start_date,
                        :base_regulation__validity_start_date,
                        :modification_regulation__validity_start_date)
      end

      def effective_end_date_column
        Sequel.function(:coalesce,
                        :measures__validity_end_date,
                        :base_regulation__effective_end_date,
                        :base_regulation__validity_end_date,
                        :modification_regulation__effective_end_date,
                        :modification_regulation__validity_end_date)
      end

      def with_generating_regulation
        association_left_join(:base_regulation, :modification_regulation)
          .where do |_query|
            (Sequel.qualify(:base_regulation, :base_regulation_id) !~ nil) |
              (Sequel.qualify(:modification_regulation, :modification_regulation_id) !~ nil)
          end
      end

      def with_regulation_dates_query_non_current
        with_generating_regulation
          .select_append(Sequel.as(effective_start_date_column, :effective_start_date))
          .select_append(Sequel.as(effective_end_date_column, :effective_end_date))
      end

      def with_regulation_dates_query
        with_generating_regulation
          .select_append(Sequel.as(effective_start_date_column, :effective_start_date))
          .select_append(Sequel.as(effective_end_date_column, :effective_end_date))
          .where do |_query|
            if model.point_in_time
              start_date = effective_start_date_column
              end_date   = effective_end_date_column

              (start_date <= model.point_in_time) &
                ((end_date >= model.point_in_time) | (end_date =~ nil))
            else
              true # .where method needs _something_ to AND to the query
            end
          end
      end
    end
  end
end
