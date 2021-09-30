module RulesOfOrigin
  class Proof
    include ActiveModel::Model

    attr_accessor :scheme, :summary, :detail, :proof_class, :subtext

    def url
      all_proof_urls[proof_class] if proof_class.present?
    end

  private

    def all_proof_urls
      scheme&.scheme_set&.proof_urls || {}
    end
  end
end
