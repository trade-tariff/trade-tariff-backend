namespace :labels do
  desc 'Refresh the goods_nomenclature_labels materialized view'
  task refresh: :environment do
    puts 'Refreshing goods_nomenclature_labels materialized view...'

    start_time = Time.current
    GoodsNomenclatureLabel.refresh!(concurrently: false)
    duration = (Time.current - start_time).round(2)

    puts "Refreshed in #{duration}s"
    puts "Total labels: #{GoodsNomenclatureLabel.count}"
  end

  desc 'Show label coverage statistics'
  task coverage: :environment do
    GoodsNomenclatureLabel.refresh!(concurrently: false)

    TimeMachine.now do
      total_gn = GoodsNomenclature.actual.with_leaf_column.declarable.count
      total_labels = GoodsNomenclatureLabel.count
      unlabeled = GoodsNomenclatureLabel.goods_nomenclatures_dataset.count
      coverage = total_gn.positive? ? (total_labels * 100.0 / total_gn).round(2) : 0

      puts 'Label Coverage Statistics'
      puts '-' * 30
      puts "Total Declarable GN: #{total_gn}"
      puts "Labeled:             #{total_labels}"
      puts "Unlabeled:           #{unlabeled}"
      puts "Coverage:            #{coverage}%"
    end
  end

  desc 'Enqueue label generation for all goods nomenclatures'
  task generate: :environment do
    puts 'Enqueuing label generation...'
    RelabelGoodsNomenclatureWorker.perform_async
    puts 'Done. Check Sidekiq for progress.'
  end

  desc 'Load and verify CN2026 self-texts'
  task load_self_texts: :environment do
    csv_path = ENV['CSV_PATH']
    SelfTextLookupService.csv_path = csv_path if csv_path.present?

    puts "Loading self-texts from #{SelfTextLookupService.csv_path}..."
    SelfTextLookupService.reload!
    puts "Loaded #{SelfTextLookupService.count} self-texts"

    # Show a few examples
    puts "\nSample lookups:"
    %w[0101210000 0102292100 8471300000].each do |code|
      text = SelfTextLookupService.lookup(code)
      puts "  #{code}: #{text || '(not found)'}"
    end
  end

  desc 'Re-label nodes that have generated self-texts (CHAPTER=02 to scope by chapter)'
  task relabel: :environment do
    sids = GoodsNomenclatureSelfText.select(:goods_nomenclature_sid)

    if ENV['CHAPTER'].present?
      chapter_code = ENV['CHAPTER'].ljust(10, '0')
      sids = sids.where(Sequel.like(:goods_nomenclature_item_id, "#{chapter_code[0..1]}%"))
    end

    sid_values = sids.select_map(:goods_nomenclature_sid)
    puts "Found #{sid_values.size} nodes with self-texts"

    deleted = GoodsNomenclatureLabel::Operation.where(goods_nomenclature_sid: sid_values).delete
    puts "Deleted #{deleted} existing label oplog entries"

    puts 'Refreshing materialized view...'
    GoodsNomenclatureLabel.refresh!(concurrently: false)

    unlabeled = GoodsNomenclatureLabel.goods_nomenclatures_dataset.count
    puts "#{unlabeled} nodes now unlabeled, enqueuing generation..."

    RelabelGoodsNomenclatureWorker.perform_async
    puts 'Done. Check Sidekiq for progress.'
  end

  desc 'Delete all labels and regenerate with contextual descriptions'
  task nuke_and_regenerate: :environment do
    csv_path = ENV['CSV_PATH']

    # Pre-load self-texts
    SelfTextLookupService.csv_path = csv_path if csv_path.present?
    puts "Loading self-texts from #{SelfTextLookupService.csv_path}..."

    unless File.exist?(SelfTextLookupService.csv_path)
      puts "ERROR: Self-texts CSV not found at #{SelfTextLookupService.csv_path}"
      puts 'Set CSV_PATH environment variable or place file at data/CN2026_SelfText_EN_DE_FR.csv'
      exit 1
    end

    SelfTextLookupService.reload!
    puts "Loaded #{SelfTextLookupService.count} self-texts"

    # Confirm before proceeding
    unless ENV['CONFIRM'] == 'true'
      puts "\nWARNING: This will delete ALL existing labels and regenerate them."
      puts 'Set CONFIRM=true to proceed.'
      exit 1
    end

    puts "\nDeleting all labels from oplog..."
    # Delete from oplog table directly (materialized view is read-only)
    deleted_count = GoodsNomenclatureLabel::Operation.count
    GoodsNomenclatureLabel::Operation.truncate
    puts "Deleted #{deleted_count} oplog entries"

    puts "\nRefreshing materialized view..."
    GoodsNomenclatureLabel.refresh!(concurrently: false)
    puts "Labels count after refresh: #{GoodsNomenclatureLabel.count}"

    puts "\nEnqueuing label generation..."
    RelabelGoodsNomenclatureWorker.perform_async
    puts 'Done. Check Sidekiq for progress.'
  end
end
