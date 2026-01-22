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
end
