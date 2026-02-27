module GenerateSelfText
  class SegmentExtractor
    # Matches tariff descriptions that are residual "Other" catch-all categories.
    # These need AI contextualisation to replace "Other" with parent context and
    # sibling exclusions.
    #
    # Matches (7,210 nodes):
    #   "Other"                              - bare residual (7,003 nodes)
    #   "Other, fresh or chilled"            - residual with comma qualifier (201 nodes)
    #   "Other (including factory rejects)"  - residual with parenthetical (2 nodes)
    #   "Other live animals"                 - residual with noun phrase (542 nodes)
    #   "Other cuts with bone in"            - residual with noun phrase
    #   "Of pine (pinus spp.), other"        - trailing residual marker (4 nodes)
    #
    # Does NOT match:
    #   "Other than for use in..."           - "Other than" is an exclusion phrase (2 nodes)
    #   "Camels and other camelids"          - mid-sentence plain English "other" (1,349 nodes)
    #   "...other than for slaughter"        - mid-sentence exclusion phrase
    OTHER_PATTERN = /
      \Aother\b(?!\s+than\b)  # starts with "Other" (but not "Other than")
      |                        # OR
      ,\s*other\s*\z           # ends with ", other"
    /ix

    def self.call(chapter, self_texts: {})
      new(chapter, self_texts:).call
    end

    def initialize(chapter, self_texts: {})
      @chapter = chapter
      @self_texts = self_texts
    end

    def call
      TimeMachine.now do
        nodes = load_hierarchy
        build_segments(nodes)
      end
    end

    private

    attr_reader :chapter, :self_texts

    def load_hierarchy
      loaded = Chapter.actual
        .where(goods_nomenclature_sid: chapter.goods_nomenclature_sid)
        .eager(:goods_nomenclature_descriptions,
               descendants: :goods_nomenclature_descriptions)
        .take

      return [] unless loaded

      [loaded] + loaded.descendants
    end

    def build_segments(nodes)
      nodes
        .group_by(&:depth)
        .sort_by(&:first)
        .flat_map { |_depth, depth_nodes| depth_nodes.map { |node| segment_for(node) } }
    end

    def segment_for(node)
      description = node.description_html
      is_other = other?(description)

      {
        node: {
          sid: node.goods_nomenclature_sid,
          code: node.goods_nomenclature_item_id,
          description: description,
          is_other: is_other,
          eu_self_text: SelfTextLookupService.lookup(node.goods_nomenclature_item_id),
          goods_nomenclature_class: node.goods_nomenclature_class,
          declarable: node.declarable?,
        },
        ancestor_chain: ancestor_chain_for(node),
        siblings: is_other ? siblings_for(node) : [],
      }
    end

    def ancestor_chain_for(node)
      chain = []
      current = node

      while (parent = current.associations[:parent])
        chain.unshift({
          sid: parent.goods_nomenclature_sid,
          description: parent.description_html,
          self_text: self_texts[parent.goods_nomenclature_sid],
        })
        current = parent
      end

      chain
    end

    def siblings_for(node)
      parent = node.associations[:parent]
      return [] unless parent

      siblings = parent.associations[:children] || []
      siblings
        .reject { |c| c.goods_nomenclature_sid == node.goods_nomenclature_sid }
        .map do |sibling|
          {
            sid: sibling.goods_nomenclature_sid,
            code: sibling.goods_nomenclature_item_id,
            description: sibling.description_html,
          }
        end
    end

    def other?(description)
      OTHER_PATTERN.match?(description.to_s)
    end
  end
end
