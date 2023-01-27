module RulesOfOrigin
  class Proof
    include ActiveModel::Model
    include ContentAddressableId

    attr_accessor :scheme, :summary, :detail, :proof_class, :subtext
    attr_writer :id, :content

    content_addressable_fields 'scheme_code', 'proof_class'
    delegate :scheme_code, :scheme_set, to: :scheme
    delegate :read_referenced_file, to: :scheme_set

    def url
      all_proof_urls[proof_class] if proof_class.present?
    end

    def content
      @content ||= read_referenced_file('proofs', scheme_code, "#{proof_class}.md")
    rescue Errno::ENOENT
      nil
    end

  private

    def all_proof_urls
      scheme&.scheme_set&.proof_urls || {}
    end
  end
end
