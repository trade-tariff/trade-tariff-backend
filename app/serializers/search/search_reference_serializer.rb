module Search
  class SearchReferenceSerializer < ::Serializer
    def referenced
      TradeTariffBackend.model_serializer_for('search', __getobj__.referenced.class).new(__getobj__.referenced)
    end

    def serializable_hash(_opts = {})
      if referenced.blank?
        {}
      else
        {
          title: title,
          reference_class: referenced_class,
          reference: referenced.serializable_hash.merge(
            class: referenced_class
          )
        }
      end
    end
  end
end
