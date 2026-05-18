namespace :db do
  namespace :test do
    desc 'Populate empty materialized views after loading the test structure'
    task populate_empty_materialized_views: :environment do
      Rails.application.eager_load!
      MaterializeViewHelper.refresh_materialized_view
    end
  end
end

if Rails.env.test?
  Rake::Task['db:structure:load'].enhance do
    Rake::Task['db:test:populate_empty_materialized_views'].invoke
  end
end
