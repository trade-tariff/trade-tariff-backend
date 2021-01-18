desc 'Trigger class eager loading'
task :class_eager_load do
  Rails.application.eager_load!
end
