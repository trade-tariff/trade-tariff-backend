module GenerateSelfText
  class SegmentExtractor
    # Matches tariff descriptions that are residual "Other" catch-all categories.
    # These need AI contextualisation because "Other" alone is meaningless to traders.
    #
    # Matches:
    #   "Other"                              - bare residual (7,003 nodes)
    #   "Other, fresh or chilled"            - residual with comma qualifier (201 nodes)
    #   "Other (including factory rejects)"  - residual with parenthetical (2 nodes)
    #   "Of pine (pinus spp.), other"        - trailing residual marker (4 nodes)
    #
    # Does NOT match (these are already self-describing):
    #   "Other live animals"                 - named category starting with "Other"
    #   "Other than for use in..."           - exclusion phrase
    #   "...other than for slaughter"        - mid-sentence plain English "other"
    OTHER_PATTERN = /
      \Aother(\z|\s*[,(])  # starts with "Other" followed by end, comma, or paren
      |                     # OR
      ,\s*other\s*\z        # ends with ", other"
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
      is_other = other?(node.formatted_description)

      {
        node: {
          sid: node.goods_nomenclature_sid,
          code: node.goods_nomenclature_item_id,
          description: node.formatted_description,
          is_other: is_other,
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
          description: parent.formatted_description,
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
            description: sibling.formatted_description,
          }
        end
    end

    def other?(description)
      OTHER_PATTERN.match?(description.to_s)
    end
  end
end
