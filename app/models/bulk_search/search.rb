class BulkSearch
  class Search
    include ContentAddressableId

    content_addressable_fields :input_description

    attr_accessor :input_description,
                  :ancestor_digits,
                  :search_result_ancestors

    def self.build(attributes)
      search = new

      search.input_description = attributes[:input_description]
      search.ancestor_digits = attributes[:ancestor_digits]
      search.search_result_ancestors = attributes[:search_result_ancestors].map do |ancestor_attributes|
        SearchAncestor.build(ancestor_attributes.symbolize_keys!)
      end

      search
    end

    def search_result_ancestor_ids
      search_result_ancestors.map(&:id)
    end
  end
end
