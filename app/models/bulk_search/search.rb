class BulkSearch
  class Search
    include ContentAddressableId

    content_addressable_fields :input_description

    attr_accessor :input_description

    def initialize(input_description, search_result_ancestors = [])
      @input_description = input_description
      @search_result_ancestors = search_result_ancestors.map do |attributes|
        SearchAncestor.build(attributes.symbolize_keys!)
      end
    end

    def search_result_ancestors
      @search_result_ancestors ||= []
    end

    def search_result_ancestor_ids
      search_result_ancestors.map(&:id)
    end

    def as_json(_options = {})
      {
        input_description:,
        search_result_ancestors:,
      }
    end
  end
end
