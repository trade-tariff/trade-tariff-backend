# frozen_string_literal: true

namespace :search_analytics do
  desc 'Refresh search analytics materialized views. The refresh sets temp_file_limit; the operator role must be allowed to SET that parameter. WAIT=true waits for an occupied lock. FORCE=true rebuilds even when source revisions match.'
  task refresh_views: :environment do
    refreshed = SearchAnalytics::MaterializedViews.refresh!(
      wait: %w[true 1].include?(ENV['WAIT'].to_s.downcase),
      force: %w[true 1].include?(ENV['FORCE'].to_s.downcase),
    )
    if refreshed
      puts 'Refreshed search analytics materialized views'
    else
      puts 'Search analytics materialized views already match source revisions'
    end
  rescue Sequel::AdvisoryLockError
    abort 'Another search analytics view refresh is running. Wait for it to finish, then retry.'
  end
end
