# Import TARIC or CDS file manually. Usually for initial seed files.
namespace :importer do
  namespace :taric do
    desc 'Import TARIC file'
    task import: %i[environment class_eager_load] do
      if ENV['TARGET'] && TariffSynchronizer::FileService.file_exists?(ENV['TARGET'])
        Sequel::Model.subclasses.each(&:unrestrict_primary_key)
        Sequel::Model.plugin :skip_create_refresh
        dummy_update = OpenStruct.new(file_path: ENV['TARGET'], issue_date: nil)
        TaricImporter.new(dummy_update).import(validate: false)
      else
        puts 'Please provide TARGET environment variable pointing to Tariff file to import'
      end
    end
  end

  namespace :cds do
    desc 'Import CDS file'
    task import: %i[environment class_eager_load] do
      if ENV['TARGET'] && TariffSynchronizer::FileService.file_exists?(ENV['TARGET'])
        Sequel::Model.subclasses.each(&:unrestrict_primary_key)
        Sequel::Model.plugin :skip_create_refresh
        dummy_update = OpenStruct.new(file_path: ENV['TARGET'], issue_date: nil)

        CdsImporter.new(dummy_update).import
      else
        puts 'Please provide TARGET environment variable pointing to Tariff file to import'
      end
    end
  end
end
