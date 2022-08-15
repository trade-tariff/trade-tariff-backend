# frozen_string_literal: true

module RulesOfOrigin
  class OriginReferenceDocument
    include ActiveModel::Model

    attr_accessor :ord_title, :ord_version, :ord_date, :ord_original
    attr_writer :id

    def id
      @id = "origin_reference_document_id"
    end
  end
end
