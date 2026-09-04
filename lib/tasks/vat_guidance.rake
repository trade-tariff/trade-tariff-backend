# rubocop:disable Metrics/BlockLength
namespace :vat_guidance do
  desc 'Build the VAT guidance context graph from GOV.UK Content API documents'
  task context_graph: :environment do
    source = VatGuidance::ContextGraphSource.new(
      source_directory: ENV['VAT_GUIDANCE_SOURCE_DIR'],
    ).call
    graph = VatGuidance::ContextGraphBuilder.new(
      source.payloads,
      commodity_contexts: VatGuidance::CommodityContextCatalog.all,
      source_failures: source.failures,
      path_aliases: source.path_aliases,
      root_paths: source.root_paths,
    ).call
    output_path = ENV.fetch('VAT_GUIDANCE_GRAPH_PATH', Rails.root.join('data/vat_guidance/context_graph.json'))
    FileUtils.mkdir_p(File.dirname(output_path))
    File.write(output_path, "#{JSON.pretty_generate(graph)}\n")

    summary = graph.fetch('summary')
    puts "Wrote #{output_path}"
    puts "Sections captured: #{summary.fetch('sections_captured')}"
    puts "Commodities captured: #{summary.fetch('commodities_captured')}"
    puts "Reference edges: #{summary.fetch('reference_edges')}"
    puts "Cross-document edges: #{summary.fetch('cross_document_edges')}"
    puts "Unresolved references: #{summary.fetch('unresolved_references')}"
  end

  desc 'Assemble LLM context packets from the VAT guidance context graph'
  task context_packets: :environment do
    graph_path = ENV.fetch('VAT_GUIDANCE_GRAPH_PATH', Rails.root.join('data/vat_guidance/context_graph.json'))
    output_path = ENV.fetch(
      'VAT_GUIDANCE_PACKETS_PATH',
      Rails.root.join('data/vat_guidance/context_packets.json'),
    )
    packets = VatGuidance::ContextPacketAssembler.new(JSON.parse(File.read(graph_path))).call
    FileUtils.mkdir_p(File.dirname(output_path))
    File.write(output_path, "#{JSON.pretty_generate(packets)}\n")

    summary = packets.fetch('summary')
    puts "Wrote #{output_path}"
    puts "Packets assembled: #{summary.fetch('packets')}"
    puts "Sections by notice: #{summary.fetch('sections_by_notice')}"
    puts "Packets with referenced content: #{summary.fetch('packets_with_referenced_content')}"
    puts "Packets with unresolved references: #{summary.fetch('packets_with_unresolved_references')}"
    puts "Commodity packets: #{summary.fetch('commodity_packets')}"
    puts "Commodities by chapter: #{summary.fetch('commodities_by_chapter')}"
    puts "Commodity evidence references: #{summary.fetch('commodity_evidence_references')}"
  end
end
# rubocop:enable Metrics/BlockLength
