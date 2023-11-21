desc 'Trigger class eager loading'
task class_eager_load: :environment do
  Rails.application.eager_load!
end
