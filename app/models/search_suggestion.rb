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

  def custom_sti_goods_nomenclature
    if goods_nomenclature_class == 'Subheading' && goods_nomenclature.instance_of?(::Commodity)
      goods_nomenclature.cast_to_subheading
    else
      goods_nomenclature
    end
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

    def by_value(value, id = nil)
      suggestions = if id
                      where(value:, id:)
                    else
                      where(value:)
                    end
      suggestions
        .eager(:goods_nomenclature)
        .limit(2)
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

  class << self
    PRIORITIES = {
      TYPE_SEARCH_REFERENCE => 1,
      TYPE_FULL_CHEMICAL_NAME => 2,
      TYPE_GOODS_NOMENCLATURE => proc do |suggestion|
        case suggestion[:goods_nomenclature_class]
        when 'Chapter' then 1
        when 'Heading' then 2
        when 'Subheading' then 3
        when 'Commodity' then 4
        else 5
        end
      end,
      TYPE_FULL_CHEMICAL_CUS => 5,
      TYPE_FULL_CHEMICAL_CAS => 6,
    }.freeze

    def build(attributes)
      unrestrict_primary_key
      suggestion = new
      suggestion.set(attributes)
      suggestion.priority = priority_for(suggestion)
      suggestion
    end

    def priority_for(suggestion)
      priority = PRIORITIES[suggestion[:type]]

      if priority.is_a?(Proc)
        priority.call(suggestion)
      else
        priority
      end
    end
  end
end
