namespace :search_embeddings do
  desc 'Generate search_embedding and search_text for all self-text records (skips unchanged)'
  task generate: :environment do
    sids = GoodsNomenclatureSelfText
      .exclude(self_text: nil)
      .order(:goods_nomenclature_sid)
      .select_map(:goods_nomenclature_sid)

    total = sids.size
    puts "Processing #{total} self-text records (skipping unchanged)..."

    batch_size = ENV.fetch('BATCH_SIZE', 500).to_i
    processed = 0

    sids.each_slice(batch_size) do |batch|
      GoodsNomenclatureSelfText.regenerate_search_embeddings(batch)

      processed += batch.size
      if (processed % 500).zero? || processed >= total
        puts "  #{processed}/#{total} records processed"
      end
    end

    puts 'Done.'
  end
end
