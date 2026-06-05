namespace :tariff_knowledge do
  desc 'Build tariff knowledge graph from chapter and section notes and refresh declarable contexts'
  task refresh: :environment do
    result = TariffKnowledge::Pipeline.call

    puts "Loaded #{result.source_count} note sources"
    puts "Graph contains #{result.rule_count} rule nodes"
    puts "Graph contains #{result.goods_nomenclature_count} goods nomenclature nodes"
    puts "Generated #{result.context_count} declarable contexts"
    puts "Coverage #{result.coverage.ok? ? 'passed' : 'failed'}"
    result.coverage.findings.each do |finding|
      puts "#{finding.severity.upcase}: #{finding.code} (#{finding.count}) - #{finding.message}"
    end

    abort 'Tariff knowledge coverage failed' unless result.coverage.ok?
  end

  desc 'Check tariff knowledge graph coverage against approved actual customs tariff notes'
  task coverage: :environment do
    result = TariffKnowledge::CoverageAnalyzer.call

    puts "Expected sources: #{result.expected_source_count}"
    puts "Actual source nodes: #{result.actual_source_count}"
    puts "Rule nodes: #{result.rule_count}"
    puts "applies_to edges: #{result.applies_to_edge_count}"
    puts "Declarable contexts: #{result.context_count}"
    puts "Coverage #{result.ok? ? 'passed' : 'failed'}"
    result.findings.each do |finding|
      puts "#{finding.severity.upcase}: #{finding.code} (#{finding.count}) - #{finding.message}"
    end

    abort 'Tariff knowledge coverage failed' unless result.ok?
  end
end
