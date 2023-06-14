class BulkSearch
  class Search
    include ContentAddressableId

    content_addressable_fields :input_description

    attr_accessor :input_description, :ancestor_digits

    def initialize(attributes)
      @input_description = attributes[:input_description]
      @ancestor_digits = attributes[:ancestor_digits]
      @search_result_ancestors = attributes[:search_result_ancestors].map do |ancestor_attributes|
        SearchAncestor.build(ancestor_attributes.symbolize_keys!)
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
