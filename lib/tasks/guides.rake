require_relative '../../db/import_guides'

namespace :guides do
  desc 'Import guides as well as guide heading and chapter associations. These are used to provide guidance on how to find commodities within headings and chapters.'
  task seed_guides: :environment do
    ImportGuides.seed_guides
  end
end
