class SearchAnalyzer
  attr_reader :filename, :searches

  def initialize(filename:)
    @filename = filename
    @searches = extract_searches
  end

  def failed_searches
    no_synonym_searches = remove_synonyms
    no_heading_searches = remove_headings(no_synonym_searches)
    no_match_searches = remove_commodities(no_heading_searches)
    generate_csv(no_match_searches)
  end

  private

  def extract_searches
    searches = []

    CSV.foreach(@filename).with_index do |row, rowno|
      next if rowno < 7
      next if row[0].nil? || row[0] == 'trade_tariff'

      searches << { term: row[0], count: row[1] }
    end

    searches
  end

  def remove_synonyms
    no_synonym_searches = []
    @searches.map do |search|
      no_synonym_searches << search unless SearchReference.where(title: search[:term]).count.positive?
    end

    no_synonym_searches
  end

  def remove_headings(searches)
    no_heading_searches = []
    searches.map do |search|
      no_heading_searches << search unless Heading.where(goods_nomenclatures__goods_nomenclature_item_id: "#{search[:term]}000000").count.positive? || Heading.where(goods_nomenclatures__goods_nomenclature_item_id: search[:term]).count.positive?
    end

    no_heading_searches
  end

  def remove_commodities(searches)
    no_match_searches = []
    searches.map do |search|
      no_match_searches << search unless Commodity.where(goods_nomenclature_item_id: search[:term]).count.positive?
    end

    no_match_searches
  end

  def generate_csv(searches)
    CSV.open('searches_without_match_or_synonym.csv', 'w') do |csv|
      csv << ['search term', 'search count']
      searches.each do |search|
        csv << [search[:term], search[:count]]
      end
    end
  end
end
