class SearchService
  class ExactSearch < BaseSearch
    def search!
      @results = case query_string
                 when /^[0-9]{1,3}$/
                   find_chapter(query_string)
                 when /^[0-9]{4,9}$/
                   find_heading(query_string)
                 when /^[0-9]{10}$/
                   # A commodity or declarable heading may have code of
                   # 10 digits
                   find_commodity(query_string) || find_heading(query_string)
                 when /^[0-9]{11,12}$/
                   find_commodity(query_string)
                 when /\A(cas\s*)?(\d+-\d+-\d)\z/i
                   # A CAS number, in the format e.g., "178535-93-8", e.g. /\d+-\d+-\d/
                   find_by_chemical(query_string)
                 else
                   # exact match for search references
                   find_search_reference(query_string)
                 end

      self
    end

    def present?
      !query_string.in?(HiddenGoodsNomenclature.codes) && results.present?
    end

    def serializable_hash
      {
        type: 'exact_match',
        entry: {
          endpoint: results.class.name.parameterize(separator: '_').pluralize,
          id: results.to_param
        }
      }
    end

    private

    def find_heading(query)
      query = SearchService::CodesMapping.check(query) || query

      Heading.actual
             .by_code(query)
             .non_hidden
             .first
    end

    def find_commodity(query)
      query = SearchService::CodesMapping.check(query) || query

      commodity = Commodity.actual
                           .by_code(query)
                           .non_hidden
                           .declarable
                           .first

      # NOTE at the moment scope .declarable is not enough to
      # determine if it is really declarable or not
      (commodity.present? && commodity.declarable?) ? commodity : nil
    end

    def find_chapter(query)
      Chapter.actual
             .by_code(query.to_s.rjust(2, '0'))
             .non_hidden
             .first
    end

    def find_search_reference(query)
      item = SearchReference.where(title: query).first.try(:referenced)
      return nil if item && item.try(:validity_end_date) && item.validity_end_date < date
      item
    end

    def find_by_chemical(query)
      matchdata = /\A(cas\s*)?(\d+-\d+-\d)\z/i.match(query)
      q = matchdata ? matchdata[2] : query.gsub(/\Acas\s+/i, '')

      if c = Chemical.first(cas: q)
        gns = c.goods_nomenclatures.map do |gn|
          ExactSearch.new(gn.goods_nomenclature_item_id, date).search!.results
        end
  
        # Each Chemical should map to only one Goods Nomenclaure,
        # but the database includes two chemicals that belong to more than one GN
        # These "chemicals" are probably placeholders and are not really correct
        return gns.first if gns.length == 1
      end
    end
  end
end
