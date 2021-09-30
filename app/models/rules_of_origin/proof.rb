module RulesOfOrigin
  class Proof
    include ActiveModel::Model

    attr_accessor :scheme, :summary, :detail
    attr_writer :id

    def content
      @content ||= if detail.present?
                     scheme.read_referenced_file('proofs', detail)
                   else
                     ''
                   end
    end

    def id
      @id ||= Digest::MD5.hexdigest("#{summary}-#{detail}")
    end
  end
end
