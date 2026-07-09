require_relative '../../app/lib/admin_configuration_seeder'

namespace :admin_configurations do
  # Seed values should align with AdminConfiguration::DEFAULTS
  desc 'Seed initial admin configurations'
  task seed: :environment do
    AdminConfigurationSeeder.seed
  end

  desc 'Reset and reseed all admin configurations'
  task reseed: :environment do
    Version.where(item_type: 'AdminConfiguration').delete
    AdminConfiguration.truncate
    puts '  truncated admin configurations'

    Rake::Task['admin_configurations:seed'].invoke
  end
end
