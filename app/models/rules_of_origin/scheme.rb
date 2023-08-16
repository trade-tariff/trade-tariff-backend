# frozen_string_literal: true

module RulesOfOrigin
  class Scheme
    include ActiveModel::Model

    attr_accessor :scheme_set, :scheme_code, :title, :ord, :introductory_notes_file,
                  :fta_intro_file, :countries, :footnote, :adopted_by_uk, :country_code, :notes,
                  :unilateral, :proof_intro

    attr_reader :cumulation_methods, :validity_start_date, :validity_end_date

    attr_writer :rule_sets, :proof_codes, :show_proofs_for_geographical_areas

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

    def show_proofs_for_geographical_areas
      @show_proofs_for_geographical_areas || []
    end

    def cumulation_methods=(cumulation_methods_data)
      @cumulation_methods = cumulation_methods_data.transform_values do |value|
        case value
        when Hash then Array.wrap(value['countries'])
        else Array.wrap(value)
        end
      end
    end

    def articles=(value); end
    def features=(value); end

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

    def proof_codes
      @proof_codes ||= {}
    end

    def validity_start_date=(value)
      @validity_start_date = parse_date(value, :beginning_of_day)
    end

    def validity_end_date=(value)
      @validity_end_date = parse_date(value, :end_of_day)
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

    def has_article?(article_name)
      articles.find { |article| article.article == article_name }
              &.content.present?
    end

    def valid_for_today?
      !(validity_start_date&.>(Time.zone.now) || validity_end_date&.<(Time.zone.now))
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

    def parse_date(value, date_cast)
      case value
      when ::String
        Time.zone.parse(value)&.public_send(date_cast)
      when ::Time, ::ActiveSupport::TimeWithZone, ::DateTime
        value
      when ::Date
        value.to_time.public_send(date_cast)
      when nil
        nil
      end
    end
  end
end
