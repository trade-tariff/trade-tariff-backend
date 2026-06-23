module TariffKnowledge
  class GraphQuery
    DEFAULT_MAX_DEPTH = 1
    HARD_MAX_DEPTH = 3
    DEFAULT_MAX_NODES = 100
    HARD_MAX_NODES = 250
    DEFAULT_MAX_EDGES = 250
    HARD_MAX_EDGES = 500

    PRESETS = {
      'note_mentions' => [
        {
          'edge_type' => Edge::APPLIES_TO,
          'direction' => 'incoming',
          'node_types' => [Node::NOTE_FRAGMENT],
        },
        {
          'edge_type' => Edge::REFERENCES,
          'direction' => 'outgoing',
          'from' => 'result_nodes',
          'node_types' => [Node::RANGE],
        },
        {
          'edge_type' => Edge::EXPANDS_TO,
          'direction' => 'outgoing',
          'node_types' => [Node::GOODS_NOMENCLATURE],
        },
        {
          'edge_type' => Edge::CONTAINS,
          'direction' => 'incoming',
          'from' => 'result_nodes',
          'node_types' => [Node::NOTE_SOURCE],
        },
      ].freeze,
    }.freeze

    def self.call(attributes)
      new(attributes).call
    end

    def initialize(attributes)
      @attributes = attributes.to_h.deep_stringify_keys
      @errors = []
      @nodes_by_id = {}
      @edges_by_id = {}
      @primary_node_ids = []
      @truncated = false
      @truncation_reason = nil
    end

    def call
      validate
      return { errors: } if errors.any?

      traverse

      {
        data: primary_nodes.map { |node| node_resource(node) },
        included: included_resources,
        meta: {
          subject_count: subject_nodes.size,
          result_count: primary_nodes.size,
          truncated:,
          truncation_reason:,
        }.compact,
      }
    end

    private

    attr_reader :attributes, :errors, :truncated, :truncation_reason

    def validate
      validate_limits
      validate_traversals
      errors << error('/data/attributes/subjects', 'subjects must resolve at least one graph node') if subject_nodes.empty?
    end

    def validate_limits
      if max_depth > HARD_MAX_DEPTH
        errors << error('/data/attributes/traversals/0/max_depth', "max_depth must be less than or equal to #{HARD_MAX_DEPTH}")
      end

      if max_nodes > HARD_MAX_NODES
        errors << error('/data/attributes/limits/max_nodes', "max_nodes must be less than or equal to #{HARD_MAX_NODES}")
      end

      if max_edges > HARD_MAX_EDGES
        errors << error('/data/attributes/limits/max_edges', "max_edges must be less than or equal to #{HARD_MAX_EDGES}")
      end
    end

    def validate_traversals
      if traversals.empty?
        errors << error('/data/attributes/traversals', 'traversals must be supplied unless a supported preset is used')
      end

      traversals.each_with_index do |traversal, index|
        unless edge_types.include?(traversal['edge_type'])
          errors << error("/data/attributes/traversals/#{index}/edge_type", "edge_type must be one of #{edge_types.join(', ')}")
        end

        unless %w[incoming outgoing].include?(traversal['direction'])
          errors << error("/data/attributes/traversals/#{index}/direction", 'direction must be incoming or outgoing')
        end
      end
    end

    def error(pointer, detail)
      {
        pointer:,
        detail:,
      }
    end

    def traverse
      current_nodes = subject_nodes

      traversals.each_with_index do |traversal, index|
        break if truncated

        source_nodes = traversal['from'] == 'result_nodes' ? primary_nodes : current_nodes
        edges = matching_edges(source_nodes, traversal)
        register_edges(edges)

        connected_nodes = connected_nodes(edges, traversal)
        connected_nodes = connected_nodes.select { |node| traversal['node_types'].include?(node.node_type) } if traversal['node_types'].present?
        register_nodes(connected_nodes)

        if index.zero?
          @primary_node_ids = connected_nodes.map(&:id)
        end

        current_nodes = connected_nodes
      end
    end

    def matching_edges(nodes, traversal)
      return [] if nodes.empty?

      id_column = traversal['direction'] == 'incoming' ? :target_node_id : :source_node_id
      Edge
        .where(relationship_type: traversal['edge_type'], id_column => nodes.map(&:id))
        .limit(remaining_edge_capacity + 1)
        .all
        .tap { |edges| truncate!('max_edges') if edges.size > remaining_edge_capacity }
        .first(remaining_edge_capacity)
    end

    def connected_nodes(edges, traversal)
      id_method = traversal['direction'] == 'incoming' ? :source_node_id : :target_node_id
      ids = edges.map(&id_method).uniq
      Node
        .where(id: ids)
        .limit(remaining_node_capacity + 1)
        .all
        .tap { |nodes| truncate!('max_nodes') if nodes.size > remaining_node_capacity }
        .first(remaining_node_capacity)
    end

    def truncate!(reason)
      @truncated = true
      @truncation_reason = reason if @truncation_reason.blank?
    end

    def register_nodes(nodes)
      nodes.each { |node| @nodes_by_id[node.id] ||= node }
    end

    def register_edges(edges)
      edges.each { |edge| @edges_by_id[edge.id] ||= edge }
    end

    def subject_nodes
      @subject_nodes ||= resolve_subjects.tap { |nodes| register_nodes(nodes) }
    end

    def resolve_subjects
      subjects.flat_map { |subject| resolve_subject(subject) }.uniq(&:id)
    end

    def resolve_subject(subject)
      return Node.by_key(subject['node_key']).all if subject['node_key'].present?

      case subject['type']
      when Node::GOODS_NOMENCLATURE
        resolve_goods_nomenclature(subject.fetch('identifiers', {}))
      else
        []
      end
    end

    def resolve_goods_nomenclature(identifiers)
      dataset = Node.goods_nomenclatures
      clauses = []
      clauses << { goods_nomenclature_sid: identifiers['goods_nomenclature_sid'].to_i } if identifiers['goods_nomenclature_sid'].present?
      clauses << { goods_nomenclature_item_id: identifiers['goods_nomenclature_item_id'].to_s } if identifiers['goods_nomenclature_item_id'].present?
      return [] if clauses.empty?

      clauses
        .map { |clause| dataset.where(clause) }
        .reduce(:union)
        .all
    end

    def primary_nodes
      @primary_node_ids.map { |id| @nodes_by_id[id] }.compact
    end

    def included_resources
      included = []
      edge_resources = @edges_by_id.values.sort_by(&:id).map { |edge| edge_resource(edge) }
      node_resources = included_nodes.map { |node| node_resource(node) }
      included.concat(edge_resources)
      included.concat(node_resources)
      included
    end

    def included_nodes
      primary_ids = primary_nodes.map(&:id)
      @nodes_by_id.values.reject { |node| primary_ids.include?(node.id) }.sort_by(&:key)
    end

    def node_resource(node)
      {
        type: 'knowledge_graph_node',
        id: node.key,
        attributes: {
          node_type: node.node_type,
          key: node.key,
          title: node.title,
          content: node.content,
          source_type: node.source_type,
          source_id: node.source_id,
          source_version: node.source_version,
          goods_nomenclature_item_id: node.goods_nomenclature_item_id,
          goods_nomenclature_sid: node.goods_nomenclature_sid,
          producline_suffix: node.producline_suffix,
          goods_nomenclature_type: node.goods_nomenclature_type,
        }.compact,
      }
    end

    def edge_resource(edge)
      {
        type: 'knowledge_graph_edge',
        id: edge.id.to_s,
        attributes: {
          relationship_type: edge.relationship_type,
        },
        relationships: {
          source: { data: resource_identifier(@nodes_by_id[edge.source_node_id]) },
          target: { data: resource_identifier(@nodes_by_id[edge.target_node_id]) },
        },
      }
    end

    def resource_identifier(node)
      return unless node

      {
        type: 'knowledge_graph_node',
        id: node.key,
      }
    end

    def subjects
      Array(attributes['subjects'])
    end

    def traversals
      @traversals ||= begin
        configured = Array(attributes['traversals']).map(&:to_h).map(&:deep_stringify_keys)
        configured.presence || PRESETS.fetch(attributes['preset'].to_s, [])
      end
    end

    def max_depth
      @max_depth ||= traversals.map { |traversal| traversal['max_depth'].presence || limits['max_depth'].presence || DEFAULT_MAX_DEPTH }.map(&:to_i).max || DEFAULT_MAX_DEPTH
    end

    def max_nodes
      @max_nodes ||= (limits['max_nodes'].presence || DEFAULT_MAX_NODES).to_i
    end

    def max_edges
      @max_edges ||= (limits['max_edges'].presence || DEFAULT_MAX_EDGES).to_i
    end

    def remaining_node_capacity
      [max_nodes - @nodes_by_id.size, 0].max
    end

    def remaining_edge_capacity
      [max_edges - @edges_by_id.size, 0].max
    end

    def limits
      @limits ||= attributes.fetch('limits', {}).to_h
    end

    def edge_types = Edge::TYPES
  end
end
