namespace :tariff do
  desc 'Reindex relevant entities on ElasticSearch'
  task reindex: %w[environment] do
    TradeTariffBackend.reindex
  end

  desc 'List queued jobs'
  task jobs: %w[environment] do
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

  desc 'Download and apply Taric or CDS data using Sidekiq'
  task sync: %w[environment sync:download_apply_and_reindex]

  namespace :sync do
    desc 'Update database by downloading and then applying TARIC or CDS updates via worker'
    task download_apply_and_reindex: %i[environment class_eager_load] do
      if TradeTariffBackend.uk?
        CdsUpdatesSynchronizerWorker.perform_async(true, true)
      else
        TaricUpdatesSynchronizerWorker.perform_async(true)
      end
    end

    desc 'Download pending Taric or CDS update files, Update tariff_updates table'
    task download: %i[environment class_eager_load] do
      if TradeTariffBackend.uk?
        CdsSynchronizer.download
      else
        TaricSynchronizer.download
      end
    end

    desc 'Apply pending updates for Taric or CDS'
    task apply: %i[environment class_eager_load] do
      if TradeTariffBackend.uk?
        CdsSynchronizer.apply
      else
        TaricSynchronizer.apply
      end
    end

    desc 'Rollback to specific date in the past'
    task rollback: %w[environment class_eager_load] do
      if ENV['DATE']
        if TradeTariffBackend.uk?
          CdsSynchronizer.rollback(ENV['DATE'], keep: ENV['KEEP'])
        else
          TaricSynchronizer.rollback(ENV['DATE'], keep: ENV['KEEP'])
        end
      else
        raise ArgumentError, "Please set the date using environment variable 'DATE'"
      end
    end
  end

  desc 'Import TARGET file'
  task import: %i[environment class_eager_load] do
    if ENV['TARGET'] && TariffSynchronizer::FileService.file_exists?(ENV['TARGET'])
      Sequel::Model.subclasses.each(&:unrestrict_primary_key)
      Sequel::Model.plugin :skip_create_refresh
      dummy_update = OpenStruct.new(file_path: ENV['TARGET'], issue_date: nil)

      if TradeTariffBackend.uk?
        CdsImporter.new(dummy_update).import
      else
        TaricImporter.new(dummy_update).import(validate: false)
      end
    else
      puts 'Please provide TARGET environment variable pointing to Tariff file to import'
    end
  end

  desc 'Check tree integrity - optionally for DATE'
  task check_integrity: %w[environment] do
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

  desc 'Recreate changes'
  task recreate_changes_data: %w[environment] do
    Change.db.transaction do
      Change.dataset.delete
      ChangesTablePopulator.populate_backlog
    end
  end
end
