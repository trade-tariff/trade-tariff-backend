namespace :cf do
  desc 'We should run migrations on the first application instance on dit space only;'
  task :run_migrations do
    on_dit_space = ENV['ON_DIT_SPACE'].to_i == 1
    exit(0) unless on_dit_space

    instance_index = if ENV['VCAP_APPLICATION'] && JSON.parse(ENV['VCAP_APPLICATION'])
                       JSON.parse(ENV['VCAP_APPLICATION'])['instance_index']
                     end

    exit(0) unless instance_index.zero?
  end
end
