namespace :search_analyzer do
  desc 'Determine failed searches from Google Analytics CSV and output to new CSV'
  task failed_searches: %w[environment] do
    p 'To run this task you will need to export a CSV report of search terms from the Trade Tariff Google Analytics'
    p 'Enter the filename and location of the analytics CSV'
    p 'Format should be: /path/to/file.csv'
    filename = STDIN.gets.chomp

    analyzer = SearchAnalyzer.new(filename: filename)
    p '########## STARTING ANALYSIS ##########'
    analyzer.failed_searches
    p '########## ANALYSIS COMPLETED ##########'
    p 'file output to searches_without_match_or_synonym.csv'
  end
end
