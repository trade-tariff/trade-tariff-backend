class SearchSuggestion < Sequel::Model
  ILIKE_SIMILARITY_THRESHOLD = 0.01
  SIMILARITY_THRESHOLD = 0.3

  plugin :timestamps, update_on_create: true

  set_primary_key %i[id value]

  dataset_module do
    def fuzzy_search(query)
      case query
      when nil, ''
        []
      when /^\d{10}$/
        where(value: query)
        .with_query(query)
        .with_score(query)
        .limit(1)
        .all
      when /^\d+$/
        where(Sequel.ilike(:value, "#{query}%"))
        .with_query(query)
        .with_score(query)
        .order(
          Sequel.asc(Sequel.function(:length, :value)),
          Sequel.asc(:value),
        )
      else
        suggestions = where(id: distinct_values(query).from_self.select(:id))
          .with_query(query)
          .with_score(query)
          .order(Sequel.desc(:score))
          .limit(10)
          .all

        suggestions.select do |suggestion|
          # ilike filters can return suggestions with a score of 0
          suggestion[:score] > ILIKE_SIMILARITY_THRESHOLD
        end
      end
    end

    def distinct_values(query)
      ilike_filter = Sequel.ilike(:value, "%#{query}%")
      similarity_filter = Sequel.lit(
        "similarity(value, ?) > #{SIMILARITY_THRESHOLD}",
        query,
      )

      where(ilike_filter)
        .or(similarity_filter)
        .with_score(query)
        .distinct(:value)
    end

    def with_query(query)
      select_append(Sequel.as(query.to_s, :query))
    end

    def with_score(query)
      select_append(Sequel.function(:similarity, :value, query).as(:score))
    end
  end
end
