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

  desc 'Run the explicit AI-1145 LLM generation sweep for every context packet'
  # This offline task intentionally avoids booting the database-backed Rails environment.
  # rubocop:disable Rails/RakeEnvironment
  task :generate_question_journey_candidates do
    unless ENV['CONFIRM_AI_COST'] == 'true'
      abort 'Set CONFIRM_AI_COST=true to acknowledge one model call per packet; each call may make up to 3 HTTP attempts'
    end

    require 'active_support/all'
    require_relative '../../app/lib/ai_usage'
    require_relative '../../app/lib/ai_usage/pricing_calculator'
    require_relative '../../app/lib/openai_client'
    require_relative '../../app/services/ai_response_sanitizer'
    require_relative '../../app/services/extract_bottom_json'
    require_relative '../../app/services/vat_guidance/question_journey_contract'
    require_relative '../../app/services/vat_guidance/question_journey_validator'
    require_relative '../../app/services/vat_guidance/question_journey_generator'
    require_relative '../../app/services/vat_guidance/question_journey_generation_sweep'

    packets_path = ENV.fetch(
      'VAT_GUIDANCE_PACKETS_PATH',
      Rails.root.join('data/vat_guidance/context_packets.json'),
    )
    output_path = ENV.fetch('VAT_GUIDANCE_GENERATION_OUTPUT_PATH') do
      abort 'Set VAT_GUIDANCE_GENERATION_OUTPUT_PATH; the reviewed candidate artifact is never overwritten implicitly'
    end
    candidates = VatGuidance::QuestionJourneyGenerationSweep.new(
      JSON.parse(File.read(packets_path)),
      model: ENV.fetch('VAT_GUIDANCE_GENERATION_MODEL', 'gpt-5.4'),
      reasoning_effort: ENV.fetch('VAT_GUIDANCE_REASONING_EFFORT', 'high'),
    ).call
    FileUtils.mkdir_p(File.dirname(output_path))
    File.atomic_write(output_path) { |file| file.write("#{JSON.pretty_generate(candidates)}\n") }

    failures = candidates.fetch('packet_generation_attempts').count { |attempt| attempt['status'] == 'generation_failed' }
    puts "Wrote #{output_path}"
    puts "Generation attempts: #{candidates.fetch('packet_generation_attempts').size}"
    puts "Generation failures requiring review: #{failures}"
  end
  # rubocop:enable Rails/RakeEnvironment

  desc 'Validate generated VAT question journeys and build the spike artifact'
  # This artifact-only task intentionally avoids booting the database-backed Rails environment.
  # rubocop:disable Rails/RakeEnvironment
  task :question_journeys do
    require 'active_support/all'
    require_relative '../../app/services/vat_guidance/question_journey_contract'
    require_relative '../../app/services/vat_guidance/question_journey_validator'
    require_relative '../../app/services/vat_guidance/question_journey_artifact_builder'
    require_relative '../../app/services/vat_guidance/question_journey_artifact_writer'

    repository_root = Pathname.new(File.expand_path('../..', __dir__))
    packets_path = ENV.fetch(
      'VAT_GUIDANCE_PACKETS_PATH',
      repository_root.join('data/vat_guidance/context_packets.json'),
    )
    candidates_path = ENV.fetch(
      'VAT_GUIDANCE_JOURNEY_CANDIDATES_PATH',
      repository_root.join('data/vat_guidance/question_journey_candidates.json'),
    )
    output_path = ENV.fetch(
      'VAT_GUIDANCE_JOURNEYS_PATH',
      repository_root.join('data/vat_guidance/question_journeys.json'),
    )
    artifact = VatGuidance::QuestionJourneyArtifactBuilder.new(
      JSON.parse(File.read(packets_path)),
      JSON.parse(File.read(candidates_path)),
    ).call
    summary = artifact.fetch('summary')
    if summary.fetch('invalid_journeys').positive?
      artifact.fetch('validation_reports').reject { |report| report.fetch('valid') }.each do |report|
        warn "#{report.fetch('journey_id')}: #{report.fetch('errors').join('; ')}"
      end
      abort 'Question journey validation failed; the previous artifact was preserved'
    end

    VatGuidance::QuestionJourneyArtifactWriter.new(output_path, artifact).call
    puts "Wrote #{output_path}"
    puts "Journeys: #{summary.fetch('journeys')}"
    puts "Valid journeys: #{summary.fetch('valid_journeys')}"
    puts "Invalid journeys: #{summary.fetch('invalid_journeys')}"
    puts "Notices covered: #{summary.fetch('notices_covered')}"
    puts "Commodity chapters: #{summary.fetch('commodity_chapters')}"
  end
  # rubocop:enable Rails/RakeEnvironment
end
# rubocop:enable Metrics/BlockLength
