module BulkSearch
  class Search
    include ContentAddressableId

    content_addressable_fields :input_description

    attr_accessor :input_description,
                  :number_of_digits,
                  :search_result_ancestors

    def self.build(attributes)
      search = new

      search.input_description = attributes[:input_description]
      search.number_of_digits = attributes[:number_of_digits]
      search.search_result_ancestors = attributes[:search_result_ancestors].map do |result|
        SearchAncestor.build(result.symbolize_keys!)
      end

      search
    end

    def search_result_ancestor_ids
      search_result_ancestors.map(&:id)
    end
  end
end
