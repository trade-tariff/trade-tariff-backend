namespace :chapters do
  desc 'Import guides for chapters and populate m-t-m association table'
  task create_guides: :environment do
    ENV['RUNNING_TASK'] = 'enabled'
    load(File.join(Rails.root, 'db', 'import_chapter_guides.rb'))
    ENV.delete('RUNNING_TASK')
  end

  desc 'Import forum links for chapters'
  task create_forum_links: :environment do
    ENV['RUNNING_TASK'] = 'enabled'
    load(File.join(Rails.root, 'db', 'import_forum_links.rb'))
    ENV.delete('RUNNING_TASK')
  end
end
