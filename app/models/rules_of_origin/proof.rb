module RulesOfOrigin
  class Proof
    include ActiveModel::Model

    attr_accessor :scheme, :summary, :detail

    def content
      @content ||= if detail.present?
                     scheme.read_referenced_file('proofs', detail)
                   else
                     ''
                   end
    end
  end
end
