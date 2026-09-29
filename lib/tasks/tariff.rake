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

  # Starts a gold query set from the command line. It calls the same service as the admin
  # API, so the checks, the random sampling and the background job are identical.
  #
  #   NAME='Set A' SIZE=100 [ATAR_PERCENTAGE=100] bundle exec rake tariff:evaluation:generate_gold_queries
  #
  # ATAR_PERCENTAGE defaults to 100 (real ATaR rulings only), which is what this task did
  # before gold query sets existed. It does not wait: generation runs on Sidekiq.
  def generate_evaluation_gold_queries
    abort 'NAME is required, for example NAME="Set A"' if ENV['NAME'].blank?
    abort 'SIZE is required, for example SIZE=100' if ENV['SIZE'].blank?

    set = Evaluation::GoldQuerySetCreator.call(
      name: ENV['NAME'],
      requested_size: ENV['SIZE'],
      atar_percentage: ENV.fetch('ATAR_PERCENTAGE', '100'),
      created_by: "rake:#{ENV.fetch('USER', 'unknown')}",
    )
    abort "Gold query set not created: #{set.errors.full_messages.join(', ')}" if set.errors.any?

    puts "Created gold query set #{set.id} (#{set.name}): #{set.planned_count} items planned, #{set.requested_size} requested."
    puts 'Generation runs in the background on Sidekiq.'
    puts "Follow it in a Rails console with EvaluationGoldQuerySet[#{set.id}] (status, generated_count, failed_count)."
  end

  def refresh
    require_relative '../../app/helpers/materialize_view_helper'

    concurrently = ENV['CONCURRENTLY'] == 'true'

    puts "Refreshing materialized views#{' concurrently' if concurrently}..."
    MaterializeViewHelper.refresh_materialized_view(concurrently: concurrently)
  end
end

desc 'Create a gold query set and start generating it (NAME, SIZE and optionally ATAR_PERCENTAGE)'
task 'tariff:evaluation:generate_gold_queries' => :environment do
  TariffRakeTasks.generate_evaluation_gold_queries
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
