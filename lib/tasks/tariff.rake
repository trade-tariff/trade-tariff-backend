module TariffRakeTasks
module_function

  def jobs
    require 'sidekiq/api'

    Sidekiq::Queue.all.each do |queue|
      puts "\nQueue '#{queue.name}': #{queue.size}"

      queue
      .map(&:item)
      .group_by { |job| job['class'] }
      .each do |job_class, jobs|
        puts "  #{job_class}: #{jobs.size}"

        case job_class
        when 'BuildIndexPageWorker'
          jobs.pluck('args').group_by(&:second).each do |indexable, index_jobs|
            puts "    #{indexable}: #{index_jobs.length}"
          end
        end
      end
    end
  end

  def download_apply_and_reindex
    if TradeTariffBackend.uk?
      CdsUpdatesSynchronizerWorker.perform_async(true, true)
    else
      TaricUpdatesSynchronizerWorker.perform_async(true)
    end
  end

  def download
    if TradeTariffBackend.uk?
      CdsSynchronizer.download
    else
      TaricSynchronizer.download
    end
  end

  def apply
    if TradeTariffBackend.uk?
      CdsSynchronizer.apply
    else
      TaricSynchronizer.apply
    end
  end

  def rollback
    raise ArgumentError, "Please set the date using environment variable 'DATE'" unless ENV['DATE']

    if TradeTariffBackend.uk?
      CdsSynchronizer.rollback(ENV['DATE'], keep: ENV['KEEP'])
    else
      TaricSynchronizer.rollback(ENV['DATE'], keep: ENV['KEEP'])
    end
  end

  def check_integrity
    date = ENV['DATE'].presence ? Time.zone.parse(ENV['DATE']).to_day : Time.zone.today

    TimeMachine.at(date) do
      puts "Checking tree for #{date.to_formatted_s(:db)}"

      service = TreeIntegrityCheckingService.new
      if service.check!
        puts '-> VALID'
      else
        puts "-> INVALID: #{service.failures.inspect}"
      end
    end
  end

  def recreate_changes_data
    Change.db.transaction do
      Change.dataset.delete
      ChangesTablePopulator.populate_backlog
    end
  end

  def generate_evaluation_gold_queries
    # RESET=true (one-off invocation flag, same convention as DATE/KEEP/CONCURRENTLY
    # above — never a persisted .env value) wipes every existing
    # evaluation_gold_queries row first and regenerates from scratch. Default
    # (unset) is additive: only ATaRs missing at least one of the 3 personas are
    # processed, so re-running is safe and cheap.
    reset = ENV['RESET'] == 'true'
    EvaluationGoldQuery.dataset.delete if reset

    # LIMIT (one-off invocation flag, same convention as RESET above — never a
    # persisted .env value) caps how many ATaRs get processed in this invocation.
    # Unset means unlimited, so normal runs are unaffected. 0/negative are rejected
    # with a clear message instead of reaching Sequel's .limit with a bad value,
    # which raises a confusing low-level error.
    limit = Integer(ENV['LIMIT'], exception: false) if ENV['LIMIT'].present?
    raise ArgumentError, 'LIMIT must be a positive integer' if ENV['LIMIT'].present? && (limit.nil? || limit < 1)

    # An inactive gold query row (active: false) makes its ATaR look incomplete again
    # and get reprocessed below, but the row itself is never touched: persist's
    # ON CONFLICT DO NOTHING means an inactive row is neither updated nor reactivated,
    # and a new row can't be inserted in its place either.
    complete_refs = EvaluationGoldQuery
                    .where(source_type: 'atar', active: true)
                    .group(:source_id)
                    .having { count.function.* >= Evaluation::GoldQueryGenerator::TIERS.size }
                    .select(:source_id)

    # Ordered by ref (the natural key) so a LIMIT-capped run always picks the same
    # subset of ATaRs across repeated invocations, rather than an arbitrary subset
    # at Postgres's discretion.
    rulings = TariffKnowledge::PublicAtarRuling.exclude(ref: complete_refs).order(:ref)
    rulings = rulings.limit(limit) if limit

    processed = generated = failed = 0
    rulings.each do |ruling|
      processed += 1
      tiers = Evaluation::GoldQueryGenerator.call(ruling)
      if tiers
        generated += tiers.size
      else
        failed += 1
      end
    rescue StandardError => e
      failed += 1
      Rails.logger.warn("Failed to generate evaluation gold queries for ATaR #{ruling.ref}: #{e.class}: #{e.message}")
    end

    puts "ATaRs processed: #{processed}, gold queries generated: #{generated}, failed/skipped: #{failed}"

    # "every processed ATaR failed" alone doesn't prove infra is broken — nil also
    # covers ordinary content rejections. Require 3+ processed first, so a LIMIT=1/2
    # smoke test doesn't trip a false "check credentials" abort.
    abort "All #{processed} ATaRs failed gold query generation — check credentials/connectivity before re-running" if processed >= 3 && failed == processed
  end

  def refresh
    require_relative '../../app/helpers/materialize_view_helper'

    concurrently = ENV['CONCURRENTLY'] == 'true'

    puts "Refreshing materialized views#{' concurrently' if concurrently}..."
    MaterializeViewHelper.refresh_materialized_view(concurrently: concurrently)
  end
end

desc 'Reindex relevant entities on ElasticSearch'
task 'tariff:reindex' => :environment do
  TradeTariffBackend.reindex
end

desc 'List queued jobs'
task 'tariff:jobs' => :environment do
  TariffRakeTasks.jobs
end

desc 'Download and apply Taric or CDS data using Sidekiq'
task 'tariff:sync' => %w[environment tariff:sync:download_apply_and_reindex]

desc 'Update database by downloading and then applying TARIC or CDS updates via worker'
task 'tariff:sync:download_apply_and_reindex' => %i[environment class_eager_load] do
  TariffRakeTasks.download_apply_and_reindex
end

desc 'Download pending Taric or CDS update files, Update tariff_updates table'
task 'tariff:sync:download' => %i[environment class_eager_load] do
  TariffRakeTasks.download
end

desc 'Apply pending updates for Taric or CDS'
task 'tariff:sync:apply' => %i[environment class_eager_load] do
  TariffRakeTasks.apply
end

desc 'Rollback to specific date in the past'
task 'tariff:sync:rollback' => %w[environment class_eager_load] do
  TariffRakeTasks.rollback
end

desc 'Check tree integrity - optionally for DATE'
task 'tariff:check_integrity' => :environment do
  TariffRakeTasks.check_integrity
end

desc 'Recreate changes'
task 'tariff:recreate_changes_data' => :environment do
  TariffRakeTasks.recreate_changes_data
end

desc 'Populate tariff changes for the past year'
task 'tariff:populate_tariff_changes' => :environment do
  TariffChangesService.populate_backlog(from: Time.zone.today - 1.year)
end

desc 'Refresh materialized views'
task 'tariff:refresh' => :environment do
  TariffRakeTasks.refresh
end

desc 'Generate evaluation gold queries from ATaR rulings (RESET=true wipes and regenerates all)'
task 'tariff:evaluation:generate_gold_queries' => :environment do
  TariffRakeTasks.generate_evaluation_gold_queries
end
