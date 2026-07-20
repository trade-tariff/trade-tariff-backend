class LabelSelfTextLoader
  SAMPLE_CODES = %w[0101210000 0102292100 8471300000].freeze

  class << self
    def call
      csv_path = ENV['CSV_PATH']
      SelfTextLookupService.csv_path = csv_path if csv_path.present?
      $stdout.puts "Loading self-texts from #{SelfTextLookupService.csv_path}..."
      SelfTextLookupService.reload!
      $stdout.puts "Loaded #{SelfTextLookupService.count} self-texts"
      print_samples
    end

  private

    def print_samples
      $stdout.puts "\nSample lookups:"
      SAMPLE_CODES.each do |code|
        text = SelfTextLookupService.lookup(code)
        $stdout.puts "  #{code}: #{text || '(not found)'}"
      end
    end
  end
end
