module SearchReferencesTasks
module_function

  DEFAULT_FPO_CSV = 'data/fpo_extra_references.csv'.freeze

  def import_fpo
    abort 'FPO search references are imported only in the UK service. Set SERVICE=uk.' unless TradeTariffBackend.uk?

    csv_path = ENV.fetch('CSV', Rails.root.join(DEFAULT_FPO_CSV).to_s)
    dry_run = ENV['DRY_RUN'].to_s.downcase == 'true'
    whodunnit = ENV.fetch('WHODUNNIT', SearchReferences::FpoCsvImporter::DEFAULT_WHODUNNIT)

    SearchReferences::FpoCsvImporter.call(csv_path, dry_run:, whodunnit:)
  rescue ArgumentError => e
    abort e.message
  end
end

namespace :search_references do
  desc 'Import FPO extra references (usage=fpo) from CSV. CSV=path (default data/fpo_extra_references.csv), DRY_RUN=true to preview, WHODUNNIT=author for paper trail versions (default fpo_csv_import)'
  task(import_fpo: :environment) { SearchReferencesTasks.import_fpo }
end
