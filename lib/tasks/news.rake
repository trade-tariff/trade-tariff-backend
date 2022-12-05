namespace :news do
  desc 'Import news stories copied from govuk'
  task import_govuk_stories: :environment do
    News::Importer.import!
  end
end
