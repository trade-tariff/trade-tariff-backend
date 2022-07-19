namespace :chapters do
  desc 'Import forum links for chapters'
  task create_forum_links: :environment do
    file = Rails.root.join('db/import_forum_links.rb')

    load(file)
  end
end
