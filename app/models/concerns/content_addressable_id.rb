require 'digest'

module ContentAddressableId
  extend ActiveSupport::Concern

  module ClassMethods
    def content_addressable_fields(*fields)
      if fields.any?
        @content_addressable_fields = fields
      else
        @content_addressable_fields
      end
    end
  end

  def id
    @id ||= Digest::MD5.hexdigest(addressable_content)
  end

  private

  def addressable_content
    self.class.content_addressable_fields
              .map(&method(:stringify_field_for_addressable_content))
              .join("\n")
  end

  def stringify_field_for_addressable_content(field)
    value = public_send(field)
    value.is_a?(Array) ? value.map(&:to_s).join("\n") : value.to_s
  end
end
