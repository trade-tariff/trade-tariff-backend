# frozen_string_literal: true

namespace :search_analytics do
  desc 'Rebuild the search analytics read model (FROM and TO optional UTC dates). The rebuild sets temp_file_limit; the operator role must be allowed to SET that parameter.'
  task rebuild_read_model: :environment do
    model = SearchAnalytics::ReadModelRefresh.call(
      region: ENV.fetch('AWS_REGION', ENV.fetch('AWS_DEFAULT_REGION', 'eu-west-2')),
      from: ENV['FROM'].presence,
      to: ENV['TO'].presence,
    )
    puts "Read model #{model.id} for #{model.service} #{model.region} version #{model.version}"
  rescue Sequel::AdvisoryLockError
    abort 'Another read-model refresh is running. Wait for it to finish, then retry.'
  end
end
