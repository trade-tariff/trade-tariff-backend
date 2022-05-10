namespace :data do
  namespace :migrate do
    task load: :environment do # rubocop:disable Rake/Desc
      require 'data_migrator'
      db_for_current_env
    end

    desc 'Rollbacks the database one data migration and re migrate up. If you want to rollback more than one step, define STEP=x. Target specific version with VERSION=x.'
    task redo: :load do
      if ENV['VERSION']
        Rake::Task['data:migrate:down'].invoke
        Rake::Task['data:migrate:up'].invoke
      else
        Rake::Task['data:rollback'].invoke
        Rake::Task['data:migrate'].invoke
      end
    end

    desc 'Runs the "up" for a given data migration VERSION.'
    task up: :load do
      version = ENV['VERSION'] ? ENV['VERSION'].to_i : nil
      raise 'VERSION is required' unless version

      ::DataMigrator.migrate_up!(version)
    end

    desc 'Runs the "down" for a given data migration VERSION.'
    task down: :load do
      version = ENV['VERSION'] ? ENV['VERSION'].to_i : nil
      raise 'VERSION is required' unless version

      ::DataMigrator.migrate_down!(version)
    end
  end

  desc 'Migrate data to the latest version'
  task migrate: 'migrate:load' do
    ::DataMigrator.migrate_up!(ENV['VERSION'] ? ENV['VERSION'].to_i : nil)
  end

  desc 'Rollback the latest data migration file or down to specified VERSION=x'
  task rollback: 'migrate:load' do
    version = if ENV['VERSION']
                ENV['VERSION'].to_i
              else
                ::DataMigrator.previous_migration
              end
    ::DataMigrator.migrate_down! version
  end
end
