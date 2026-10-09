module SearchReferencesTasks
module_function

  DEFAULT_FPO_CSV = 'data/fpo_extra_references.csv'.freeze
  BACKFILL_WHODUNNIT = 'ClearInvalidSearchReferences (backfill)'.freeze

  def import_fpo
    abort 'FPO search references are imported only in the UK service. Set SERVICE=uk.' unless TradeTariffBackend.uk?

    csv_path = ENV.fetch('CSV', Rails.root.join(DEFAULT_FPO_CSV).to_s)
    dry_run = ENV['DRY_RUN'].to_s.downcase == 'true'
    whodunnit = ENV.fetch('WHODUNNIT', SearchReferences::FpoCsvImporter::DEFAULT_WHODUNNIT)

    SearchReferences::FpoCsvImporter.call(csv_path, dry_run:, whodunnit:)
  rescue ArgumentError => e
    abort e.message
  end

  # ClearInvalidSearchReferences used to remove references with `delete`,
  # which skipped paper trail, so their history never recorded the removal.
  # Write the missing destroy version from each orphan's last known state.
  def backfill_destroy_versions
    dry_run = ENV['DRY_RUN'].to_s.downcase == 'true'
    orphans = orphaned_search_reference_versions

    orphans.each do |version|
      puts "#{dry_run ? '[DRY RUN] ' : ''}Backfilling destroy version for search reference #{version.item_id} (#{version.object['title']})"
      next if dry_run

      Version.create(
        item_type: 'SearchReference',
        item_id: version.item_id,
        event: 'destroy',
        object: Sequel.pg_jsonb_wrap(version.object.to_h),
        whodunnit: BACKFILL_WHODUNNIT,
        created_at: Time.current,
      )
    end

    puts "#{dry_run ? 'Would backfill' : 'Backfilled'} #{orphans.size} destroy version(s)"
  end

  def orphaned_search_reference_versions
    existing_ids = SearchReference.select_map(:id).to_set(&:to_s)

    Version
      .where(item_type: 'SearchReference')
      .distinct(:item_id)
      .order(:item_id, Sequel.desc(:id))
      .all
      .reject { |version| version.event == 'destroy' || existing_ids.include?(version.item_id) }
  end
end

namespace :search_references do
  desc 'Import FPO extra references (usage=fpo) from CSV. CSV=path (default data/fpo_extra_references.csv), DRY_RUN=true to preview, WHODUNNIT=author for paper trail versions (default fpo_csv_import)'
  task(import_fpo: :environment) { SearchReferencesTasks.import_fpo }

  desc 'Write missing destroy versions for search references deleted without paper trail. DRY_RUN=true to preview'
  task(backfill_destroy_versions: :environment) { SearchReferencesTasks.backfill_destroy_versions }
end
