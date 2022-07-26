module RulesOfOrigin
  class Proof
    include ActiveModel::Model
    include ContentAddressableId

    content_addressable_fields 'summary', 'proof_class'

    attr_accessor :scheme, :summary, :detail, :proof_class, :subtext
    attr_writer :id

    def url
      all_proof_urls[proof_class] if proof_class.present?
    end

  private

    def all_proof_urls
      scheme&.scheme_set&.proof_urls || {}
    end
  end
end
