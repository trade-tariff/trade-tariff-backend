namespace :news do
  desc 'Import news stories copied from govuk'
  task import_govuk_stories: :environment do
    News::Importer.import!
  end

  desc 'Assign slugs to existing news items'
  task assign_missing_slugs: :environment do
    News::Importer.assign_missing_slugs!
  end
end
