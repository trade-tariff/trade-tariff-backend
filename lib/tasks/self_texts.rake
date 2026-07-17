module SelfTextsTasks
module_function

  def coverage
    SelfTextCoverageReporter.call
  end

  def regenerate
    SelfTextRegenerator.call
  end

  def generate
    SelfTextGenerationRunner.call(ENV['CHAPTER'])
  end

  def populate_eu_references
    csv_path = Rails.root.join('data/CN2026_SelfText_EN_DE_FR.csv')
    EuReferenceSelfTextImporter.call(csv_path)
  end

  def generate_embeddings
    SelfTextEmbeddingBackfiller.call
  end

  def fix_encoding_artefacts
    sanitiser = GenerateSelfText::EncodingArtefactSanitiser
    fixed = 0

    GoodsNomenclatureSelfText.where(generation_type: %w[ai ai_non_other]).each do |record|
      fixed += fix_encoding_artefact(record, sanitiser)
    end

    puts "Done. Fixed #{fixed} records."
  end

  def fix_encoding_artefact(record, sanitiser)
    sanitised = sanitiser.call(record.self_text)
    return 0 if sanitised == record.self_text

    record.update(self_text: sanitised, embedding: nil, search_embedding: nil, search_embedding_stale: true)
    puts "Fixed [#{record.goods_nomenclature_item_id}] sid=#{record.goods_nomenclature_sid}: #{record.self_text.truncate(80)}"
    1
  end

  def score
    sids = GoodsNomenclatureSelfText.select_map(:goods_nomenclature_sid)
    puts "Scoring #{sids.size} self-texts..."
    SelfTextConfidenceScorer.new.score(sids)
    puts 'Scoring complete.'
  end

  def status
    require 'json'

    TimeMachine.now do
      print_busy_self_text_workers
      puts
      print_queued_self_text_workers
    end
  end

  def print_busy_self_text_workers
    puts 'BUSY:'
    Sidekiq::Workers.new.each do |_pid, _tid, work|
      payload = JSON.parse(work.payload)
      next unless payload['class'].include?('SelfText')

      puts "  #{chapter_label(payload['args']&.first)} (running since #{Time.zone.at(work.run_at)})"
    end
  end

  def print_queued_self_text_workers
    queued = Sidekiq::Queue.all.flat_map { |queue| queue.select { |job| job.klass.include?('SelfText') } }
    puts "QUEUED (#{queued.size}):"
    queued.each do |job|
      puts "  #{chapter_label(job.args&.first)} (enqueued #{Time.zone.at(job.enqueued_at)}) [#{job.queue}]"
    end
  end

  def chapter_label(sid)
    chapter = Chapter.where(goods_nomenclature_sid: sid).first
    chapter ? "#{chapter.goods_nomenclature_item_id.first(2)} - #{chapter.description}" : "sid=#{sid}"
  end

  def gaps
    SelfTextGapReporter.call(ENV['CHAPTER'])
  end

  def validate
    threshold = ENV.fetch('THRESHOLD', '0.7').to_f
    flag_below = ENV.key?('THRESHOLD')
    SelfTextValidationReporter.call(threshold:, flag_below:)
  end
end

namespace :self_texts do
  desc 'Show self-text coverage statistics'
  task(coverage: :environment) { SelfTextsTasks.coverage }

  desc 'Regenerate all self-texts by marking them stale and re-enqueuing'
  task(regenerate: :environment) { SelfTextsTasks.regenerate }

  desc 'Generate self-texts for all chapters (background) or a single chapter (inline with CHAPTER=XX)'
  task(generate: :environment) { SelfTextsTasks.generate }

  desc 'Populate EU reference self-texts from CSV into existing generated rows'
  task(populate_eu_references: :environment) { SelfTextsTasks.populate_eu_references }

  desc 'Generate embeddings for self-texts and EU references via OpenAI'
  task(generate_embeddings: :environment) { SelfTextsTasks.generate_embeddings }

  desc 'Fix encoding artefacts (e.g. pure9e -> puree) in existing AI-generated self-texts'
  task(fix_encoding_artefacts: :environment) { SelfTextsTasks.fix_encoding_artefacts }

  desc 'Score all self-texts (populate EU refs, generate embeddings, compute confidence)'
  task(score: :environment) { SelfTextsTasks.score }

  desc 'Show busy and queued self-text generation workers with chapter details'
  task(status: :environment) { SelfTextsTasks.status }

  desc 'Show self-text gaps and stale records grouped by chapter and heading (CHAPTER=XX to filter)'
  task(gaps: :environment) { SelfTextsTasks.gaps }

  desc 'Validate generated self-texts - report similarity and coherence scores'
  task(validate: :environment) { SelfTextsTasks.validate }
end
