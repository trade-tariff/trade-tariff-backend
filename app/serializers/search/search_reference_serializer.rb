module Search
  class SearchReferenceSerializer < ::Serializer
    def serializable_hash(_opts = {})
      if serializer_instance.blank?
        {}
      else
        {
          title:,
          reference_class: referenced_class,
          reference: serializer_instance.serializable_hash.merge(
            class: referenced_class,
          ),
        }
      end
    end

  private

    def serializer_for_referenced_class
      "Search::#{referenced.class}Serializer".constantize
    end

    def serializer_instance
      @serializer_instance ||= serializer_for_referenced_class.new(__getobj__.referenced)
    end
  end
end
