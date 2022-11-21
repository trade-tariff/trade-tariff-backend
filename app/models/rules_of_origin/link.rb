module RulesOfOrigin
  class Link
    include ActiveModel::Model
    include ContentAddressableId

    content_addressable_fields 'url', 'text'

    attr_accessor :text, :url
    attr_writer :id, :source

    class << self
      def new_with_check(attrs = {})
        attrs = attrs.stringify_keys
        return unless attrs['text'].present? && attrs['url'].present?

        new(attrs)
      end
    end

    def source
      @source || 'scheme'
    end
  end
end
