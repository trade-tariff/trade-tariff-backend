class SearchSuggestion < Sequel::Model
  ILIKE_SIMILARITY_THRESHOLD = 0.01

  TYPE_SEARCH_REFERENCE = 'search_reference'.freeze
  TYPE_GOODS_NOMENCLATURE = 'goods_nomenclature'.freeze
  TYPE_FULL_CHEMICAL_CAS = 'full_chemical_cas'.freeze
  TYPE_FULL_CHEMICAL_CUS = 'full_chemical_cus'.freeze
  TYPE_FULL_CHEMICAL_NAME = 'full_chemical_name'.freeze
  TYPE_KNOWN_BRAND = 'known_brand'.freeze
  TYPE_COLLOQUIAL_TERM = 'colloquial_term'.freeze
  TYPE_SYNONYM = 'synonym'.freeze

  plugin :timestamps, update_on_create: true

  set_primary_key %i[id value]

  many_to_one :goods_nomenclature, key: :goods_nomenclature_sid,
                                   foreign_key: :goods_nomenclature_sid,
                                   graph_use_association_block: true do |ds|
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
            Sequel.asc(:value),
          )
          .limit(10)
          .all
      else
        filtered_cte = select_all
          .distinct(:value)
          .where(type: %w[search_reference full_chemical_name])
          .where(Sequel.ilike(:value, "%#{query}%"))
          .order(:value, :priority)

        suggestions = with(:filtered, filtered_cte)
          .from(:filtered)
          .select_all(:filtered)
          .with_query(query)
          .with_score(query)
          .order(:priority, Sequel.desc(:score))
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
      where(
        type: [
          TYPE_SEARCH_REFERENCE,
          TYPE_FULL_CHEMICAL_NAME,
        ],
      )
    end

    def search_reference_type
      where(type: [TYPE_SEARCH_REFERENCE])
    end

    def numeric_type
      where(
        type: [
          TYPE_FULL_CHEMICAL_CAS,
          TYPE_FULL_CHEMICAL_CUS,
          TYPE_GOODS_NOMENCLATURE,
        ],
      )
    end

    def with_query(query)
      select_append(Sequel.as(query.to_s, :query))
    end

    def with_score(query)
      select_append(Sequel.function(:similarity, :value, query).as(:score))
    end

    def duplicates_by(field)
      most_recent_records = most_recent_by(field)

      goods_nomenclature_type
        .select(:search_suggestions__id, :search_suggestions__value)
        .left_join(
          most_recent_records.as(:recent_records),
          field => field,
        )
        .where { Sequel[:search_suggestions][:created_at] < Sequel[:recent_records][:latest_created_at] }
    end

    def most_recent_by(field)
      goods_nomenclature_type
        .select_group(field)
        .select_append { max(:created_at).as(:latest_created_at) }
    end
  end

  class << self
    PRIORITIES = {
      TYPE_SEARCH_REFERENCE => 1,
      TYPE_FULL_CHEMICAL_NAME => 2,
      TYPE_KNOWN_BRAND => 3,
      TYPE_COLLOQUIAL_TERM => 3,
      TYPE_SYNONYM => 3,
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
