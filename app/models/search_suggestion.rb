class SearchSuggestion < Sequel::Model
  ILIKE_SIMILARITY_THRESHOLD = 0.01

  TYPE_SEARCH_REFERENCE = 'search_reference'.freeze
  TYPE_GOODS_NOMENCLATURE = 'goods_nomenclature'.freeze
  TYPE_FULL_CHEMICAL_CAS = 'full_chemical_cas'.freeze
  TYPE_FULL_CHEMICAL_CUS = 'full_chemical_cus'.freeze
  TYPE_FULL_CHEMICAL_NAME = 'full_chemical_name'.freeze

  plugin :timestamps, update_on_create: true

  set_primary_key %i[id value]

  many_to_one :goods_nomenclature, key: :goods_nomenclature_sid,
                                   foreign_key: :goods_nomenclature_sid do |ds|
                                     ds.with_actual(GoodsNomenclature)
                                   end

  dataset_module do
    def fuzzy_search(query)
      case query
      when nil, ''
        []
      when /^\d{10}$/
        goods_nomenclature_type
          .where(value: query)
          .with_query(query)
          .limit(1)
          .all
      when /^\d+$/
        numeric_type
          .where(Sequel.ilike(:value, "#{query}%"))
          .with_query(query)
          .order(
            Sequel.asc(:priority),
            Sequel.asc(Sequel.function(:length, :value)),
            Sequel.asc(:value),
          )
          .limit(10)
          .all
      else
        suggestions = where(id: distinct_values(query).from_self.select(:id))
          .with_query(query)
          .with_score(query)
          .order(
            Sequel.asc(:priority),
            Sequel.desc(:score),
          )
          .limit(10)
          .all

        suggestions.select do |suggestion|
          # ilike filters can return suggestions with a score of 0
          suggestion[:score] > ILIKE_SIMILARITY_THRESHOLD
        end
      end
    end

    def by_suggestion_type_and_value(type, value)
      where(type:, value:)
        .eager(:goods_nomenclature)
        .limit(2)
        .all
    end

    def distinct_values(query)
      ilike_filter = Sequel.ilike(:value, "%#{query}%")

      text_type.where(ilike_filter).distinct(:value)
    end

    def goods_nomenclature_type
      where(type: 'goods_nomenclature')
    end

    def text_type
      if TradeTariffBackend.full_chemical_search_enabled?
        where(
          type: [
            TYPE_SEARCH_REFERENCE,
            TYPE_FULL_CHEMICAL_NAME,
          ],
        )
      else
        where(
          type: [
            TYPE_SEARCH_REFERENCE,
          ],
        )
        # TODO: remove this when we have populated all types
        .or(
          type: nil,
        )
      end
    end

    def numeric_type
      if TradeTariffBackend.full_chemical_search_enabled?
        where(
          type: [
            TYPE_FULL_CHEMICAL_CAS,
            TYPE_FULL_CHEMICAL_CUS,
            TYPE_GOODS_NOMENCLATURE,
          ],
        )
      else
        where(
          type: [
            TYPE_GOODS_NOMENCLATURE,
          ],
        )
        # TODO: remove this when we have populated all types
        .or(
          type: nil,
        )
      end
    end

    def with_query(query)
      select_append(Sequel.as(query.to_s, :query))
    end

    def with_score(query)
      select_append(Sequel.function(:similarity, :value, query).as(:score))
    end
  end
end
