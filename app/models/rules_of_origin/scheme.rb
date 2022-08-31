module RulesOfOrigin
  class Scheme
    include ActiveModel::Model

    attr_accessor :scheme_set, :scheme_code, :title, :ord, :introductory_notes_file,
                  :fta_intro_file, :countries, :footnote, :adopted_by_uk, :country_code, :notes,
                  :unilateral

    attr_writer :rule_sets

    delegate :read_referenced_file, to: :scheme_set

    def links=(links_data)
      @links = Array.wrap(links_data)
                    .map(&Link.method(:new_with_check))
                    .compact
                    .freeze
    end

    def links
      @links || []
    end

    def explainers=(explainers_data)
      @explainers = Array.wrap(explainers_data)
                         .map(&Explainer.method(:new_with_check))
                         .compact
                         .freeze
    end

    def explainers
      @explainers || []
    end

    def proofs=(proofs_data)
      @proofs = Array.wrap(proofs_data)
                     .map(&method(:new_proof))
                     .freeze
    end

    def proofs
      @proofs || []
    end

    def articles
      @articles ||= RulesOfOrigin::Article.for_scheme(self)
    end

    def fta_intro
      @fta_intro ||= if fta_intro_file.present?
                       read_referenced_file('fta_intro', fta_intro_file)
                     else
                       ''
                     end
    end

    def origin_reference_document
      @origin_reference_document = ::RulesOfOrigin::OriginReferenceDocument.new(ord)
    end

    def introductory_notes
      @introductory_notes ||= if introductory_notes_file.present?
                                read_referenced_file('introductory_notes',
                                                     introductory_notes_file)
                              else
                                ''
                              end
    end

    def rule_sets
      @rule_sets ||= RulesOfOrigin::V2::RuleSet.build_for_scheme(self, read_rule_sets)
    end

    def rule_sets_for_subheading(subheading_code)
      rule_sets.select { |rs| rs.for_subheading? subheading_code }
    end

    private

    def new_proof(proof_attrs)
      Proof.new proof_attrs.merge(scheme: self)
    end

    def read_rule_sets
      JSON.parse(read_referenced_file('rule_sets', "#{scheme_code}.json"))
    rescue Errno::ENOENT
      { 'rule_sets' => [] }
    end
  end
end
