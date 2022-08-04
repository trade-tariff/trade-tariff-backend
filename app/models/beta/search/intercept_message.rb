module Beta
  module Search
    class InterceptMessage
      include ContentAddressableId

      content_addressable_fields :intercept_message

      attr_accessor :intercept_message, :term, :message

      def self.build(search_query)
        return unless search_query.eql?((I18n.t "#{search_query}.title"))

        result = new

        result.term = I18n.t "#{search_query}.title"
        result.message = I18n.t "#{search_query}.message"

        result
      end
    end
  end
end
