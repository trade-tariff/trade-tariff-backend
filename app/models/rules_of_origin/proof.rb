module RulesOfOrigin
  class Proof
    include ActiveModel::Model

    attr_accessor :scheme, :summary, :detail, :proof_class, :subtext
  end
end
