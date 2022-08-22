module RulesOfOrigin
  class OriginReferenceDocument
    include ActiveModel::Model
    include ContentAddressableId

    attr_accessor :ord_title, :ord_version, :ord_date, :ord_original

    content_addressable_fields :ord_title,
                               :ord_version,
                               :ord_date,
                               :ord_original
  end
end
