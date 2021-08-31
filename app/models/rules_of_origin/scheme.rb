# frozen_string_literal: true

module RulesOfOrigin
  class Scheme
    include ActiveModel::Model

    attr_accessor :scheme_code, :title, :introductory_notes_file, :fta_intro_file,
                  :countries, :rule_offset, :footnote

    attr_reader :links, :explainers

    def links=(links_data)
      @links = Array.wrap(links_data)
                    .map(&Link.method(:new_with_check))
                    .compact
                    .freeze
    end

    def explainers=(explainers_data)
      @explainers = Array.wrap(explainers_data)
                         .map(&Explainer.method(:new_with_check))
                         .compact
                         .freeze
    end
  end
end
