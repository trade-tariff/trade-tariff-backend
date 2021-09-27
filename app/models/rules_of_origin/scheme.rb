# frozen_string_literal: true

module RulesOfOrigin
  class Scheme
    include ActiveModel::Model

    attr_accessor :scheme_set, :scheme_code, :title, :introductory_notes_file,
                  :fta_intro_file, :countries, :rule_offset, :footnote,
                  :adopted_by_uk, :country_code, :notes

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

    def fta_intro
      @fta_intro ||= begin
        return '' if fta_intro_file.blank?

        scheme_set.read_referenced_file('fta_intro', fta_intro_file)
      end
    end
  end
end
