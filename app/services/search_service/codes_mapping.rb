# UK Trade Tariff: correlation tables
# https://www.gov.uk/government/publications/uk-trade-tariff-correlation-tables/uk-trade-tariff-correlation-tables

class SearchService
  module CodesMapping
    def self.check(query)
      first_8 = query[0..7]
      last_n = query[8..]
      mapping = data[first_8]

      "#{mapping}#{last_n}" if mapping
    end

    def self.data
      Rails.cache.fetch('codes-mapping-2016-to-2017', expires_in: 24.hours) do
        file = Rails.root.join('db/codes-mapping-2016-to-2017.csv')
        lines = CSV.read(file, col_sep: ';')
        # O(n) solution
        lines.group_by { |l| l[0] }.select { |_, v| v.length == 1 }.map { |_, v| v[0] }.to_h
      end
    end
  end
end
