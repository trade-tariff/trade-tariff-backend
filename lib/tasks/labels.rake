namespace :labels do
  desc 'Show label coverage statistics'
  task coverage: :environment do
    TimeMachine.now do
      total_gn = GoodsNomenclature.actual.non_hidden.with_leaf_column.declarable.count
      total_labels = GoodsNomenclatureLabel.count
      coverage = total_gn.positive? ? (total_labels * 100.0 / total_gn).round(2) : 0

      base = GoodsNomenclatureLabel.declarable_nomenclatures
      unlabeled_count = base.where(GoodsNomenclatureLabel.unlabeled).count
      stale_count = base.where(GoodsNomenclatureLabel.stale_label).count
      drifted_count = base.where(GoodsNomenclatureLabel.self_text_context_changed).count
      needing_work = GoodsNomenclatureLabel.goods_nomenclatures_dataset.count

      puts 'Label Coverage Statistics'
      puts '-' * 30
      puts "Total Declarable GN: #{total_gn}"
      puts "Labeled:             #{total_labels}"
      puts "Needing work:        #{needing_work}"
      puts "  Unlabeled:         #{unlabeled_count}"
      puts "  Stale:             #{stale_count}"
      puts "  Context drifted:   #{drifted_count}"
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

  desc 'Mark all labels stale and re-label (CHAPTER=02 to scope by chapter)'
  task relabel: :environment do
    scope = GoodsNomenclatureLabel.dataset

    if ENV['CHAPTER'].present?
      scope = scope.where(Sequel.like(:goods_nomenclature_item_id, "#{ENV['CHAPTER']}%"))
    end

    updated = scope.update(stale: true, updated_at: Time.zone.now)
    puts "Marked #{updated} labels as stale"

    unlabeled = GoodsNomenclatureLabel.goods_nomenclatures_dataset.count
    puts "#{unlabeled} nodes now need relabeling, enqueuing generation..."

    RelabelGoodsNomenclatureWorker.perform_async
    puts 'Done. Check Sidekiq for progress.'
  end

  desc 'Show busy and queued label generation workers'
  task status: :environment do
    require 'json'

    puts 'BUSY:'
    Sidekiq::Workers.new.each do |_pid, _tid, work|
      payload = JSON.parse(work.payload)
      next unless payload['class'].include?('Relabel')

      puts "  #{payload['class']} args=#{payload['args']} (running since #{Time.zone.at(work.run_at)})"
    end

    puts
    queued = Sidekiq::Queue.all.flat_map do |q|
      q.select { |j| j.klass.include?('Relabel') }
    end

    puts "QUEUED (#{queued.size}):"
    queued.each do |job|
      puts "  #{job.klass} args=#{job.args} (enqueued #{Time.zone.at(job.enqueued_at)}) [#{job.queue}]"
    end
  end

  desc 'Show label gaps, stale and context-drifted records by chapter and heading (CHAPTER=XX to filter)'
  task gaps: :environment do
    TimeMachine.now do
      gn = Sequel[:goods_nomenclatures]
      lbl = Sequel[:goods_nomenclature_labels]
      st = Sequel[:goods_nomenclature_self_texts]

      # All actual declarable commodities left-joined to labels and self_texts
      base = GoodsNomenclature.actual
        .non_hidden
        .with_leaf_column
        .declarable
        .left_join(:goods_nomenclature_labels, { lbl[:goods_nomenclature_sid] => gn[:goods_nomenclature_sid] })
        .left_join(:goods_nomenclature_self_texts, { st[:goods_nomenclature_sid] => gn[:goods_nomenclature_sid] })

      if ENV['CHAPTER']
        base = base.where(Sequel.like(gn[:goods_nomenclature_item_id], "#{ENV['CHAPTER'].ljust(2, '0')}%"))
      end

      unlabeled_expr = Sequel.expr(lbl[:goods_nomenclature_sid] => nil)
      stale_expr = Sequel.&({ lbl[:stale] => true }, { lbl[:manually_edited] => false })
      drifted_expr = Sequel.&(
        { lbl[:manually_edited] => false },
        Sequel.~(st[:self_text] => nil),
        Sequel.~(lbl[:context_hash] => GoodsNomenclatureLabel.self_text_hash(st)),
      )

      needing_work_ds = base.where(unlabeled_expr | stale_expr | drifted_expr)

      # --- Chapter summary ---
      chapter_stats = base
        .select_group(Sequel.function(:substr, gn[:goods_nomenclature_item_id], 1, 2).as(:ch))
        .select_append { count(Sequel.lit('*')).as(total) }
        .select_append { count(Sequel.case([[unlabeled_expr, 1]], nil)).as(missing) }
        .select_append { count(Sequel.case([[stale_expr, 1]], nil)).as(stale) }
        .select_append { count(Sequel.case([[drifted_expr, 1]], nil)).as(drifted) }
        .order(:ch)
        .all

      chapter_descs = Chapter.actual
        .eager(:goods_nomenclature_descriptions)
        .all
        .to_h { |c| [c.goods_nomenclature_item_id.first(2), c.description&.truncate(40)] }

      puts 'Label Gaps, Stale and Context-Drifted by Chapter'
      puts '=' * 110
      printf "%-4s %-40s %6s %6s %6s %6s %6s %7s\n", 'Ch', 'Description', 'Total', 'Miss', 'Stale', 'Drift', 'Work', 'Cov %'
      puts '-' * 110

      chapter_stats.each do |row|
        ch = row[:ch]
        total = row[:total]
        miss = row[:missing]
        stale = row[:stale]
        drifted = row[:drifted]
        work = miss + stale + drifted
        cov = total.positive? ? ((total - miss) * 100.0 / total).round(1) : 0
        printf "%-4s %-40s %6d %6d %6d %6d %6d %6.1f%%\n", ch, chapter_descs[ch] || '?', total, miss, stale, drifted, work, cov
      end

      total_all = chapter_stats.sum { |r| r[:total] }
      miss_all = chapter_stats.sum { |r| r[:missing] }
      stale_all = chapter_stats.sum { |r| r[:stale] }
      drifted_all = chapter_stats.sum { |r| r[:drifted] }
      work_all = miss_all + stale_all + drifted_all
      cov_all = total_all.positive? ? ((total_all - miss_all) * 100.0 / total_all).round(1) : 0
      puts '-' * 110
      printf "%-45s %6d %6d %6d %6d %6d %6.1f%%\n", 'TOTAL', total_all, miss_all, stale_all, drifted_all, work_all, cov_all
      puts

      # --- Heading detail (only chapters with work needed) ---
      gap_chapters = chapter_stats.select { |r| (r[:missing] + r[:stale] + r[:drifted]).positive? }.map { |r| r[:ch] }

      if gap_chapters.any?
        heading_stats = needing_work_ds
          .select_group(
            Sequel.function(:substr, gn[:goods_nomenclature_item_id], 1, 2).as(:ch),
            Sequel.function(:substr, gn[:goods_nomenclature_item_id], 1, 4).as(:hd),
          )
          .select_append { count(Sequel.case([[unlabeled_expr, 1]], nil)).as(missing) }
          .select_append { count(Sequel.case([[stale_expr, 1]], nil)).as(stale) }
          .select_append { count(Sequel.case([[drifted_expr, 1]], nil)).as(drifted) }
          .order(:ch, :hd)
          .all

        heading_descs = Heading.actual
          .eager(:goods_nomenclature_descriptions)
          .all
          .to_h { |h| [h.goods_nomenclature_item_id.first(4), h.description&.truncate(40)] }

        puts 'Labels Needing Work by Heading'
        puts '=' * 90
        printf "%-6s %-40s %6s %6s %6s %6s\n", 'Head', 'Description', 'Miss', 'Stale', 'Drift', 'Work'
        puts '-' * 90

        current_ch = nil
        heading_stats.each do |row|
          if row[:ch] != current_ch
            current_ch = row[:ch]
            puts "-- Chapter #{current_ch}: #{chapter_descs[current_ch] || '?'} --"
          end
          work = row[:missing] + row[:stale] + row[:drifted]
          printf "  %-4s %-38s %6d %6d %6d %6d\n", row[:hd], heading_descs[row[:hd]] || '?', row[:missing], row[:stale], row[:drifted], work
        end
        puts

        # --- Full list of commodities needing work ---
        puts 'All Commodities Needing Work (ordered by item_id, producline_suffix)'
        puts '=' * 120
        printf "%-12s %-4s %-9s %-80s\n", 'Item ID', 'PLS', 'Reason', 'Description'
        puts '-' * 120

        work_rows = needing_work_ds
          .select(
            gn[:goods_nomenclature_sid],
            gn[:goods_nomenclature_item_id],
            gn[:producline_suffix],
            Sequel.case(
              [
                [unlabeled_expr, 'missing'],
                [stale_expr, 'stale'],
                [drifted_expr, 'drifted'],
              ],
              'unknown',
            ).as(:reason),
          )
          .order(gn[:goods_nomenclature_item_id], gn[:producline_suffix])
          .all

        if work_rows.any?
          work_sids = work_rows.map { |r| r[:goods_nomenclature_sid] }
          descriptions = GoodsNomenclature.actual
            .where(goods_nomenclature_sid: work_sids)
            .eager(:goods_nomenclature_descriptions)
            .all
            .to_h { |item| [item.goods_nomenclature_sid, item.description&.truncate(80) || '?'] }

          work_rows.each do |row|
            printf "%-12s %-4s %-9s %-80s\n",
                   row[:goods_nomenclature_item_id],
                   row[:producline_suffix],
                   row[:reason],
                   descriptions[row[:goods_nomenclature_sid]] || '?'
          end
        end

        puts '-' * 120
        puts "Total needing work: #{work_rows.size}"
      else
        puts 'No gaps found - full coverage, nothing stale or drifted!'
      end
    end
  end

  desc 'Score all labels (embed label terms and compare against self-text embeddings)'
  task score: :environment do
    sids = GoodsNomenclatureLabel.select_map(:goods_nomenclature_sid)
    puts "Scoring #{sids.size} labels..."

    scorer = LabelConfidenceScorer.new
    batch_size = ENV.fetch('BATCH_SIZE', 500).to_i

    sids.each_slice(batch_size).with_index do |batch, i|
      scorer.score(batch)
      processed = [(i + 1) * batch_size, sids.size].min
      puts "  #{processed}/#{sids.size} scored"
    end

    puts 'Scoring complete.'
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

    puts "\nDeleting all labels..."
    deleted_count = GoodsNomenclatureLabel.count
    GoodsNomenclatureLabel.dataset.delete
    puts "Deleted #{deleted_count} labels"

    puts "\nEnqueuing label generation..."
    RelabelGoodsNomenclatureWorker.perform_async
    puts 'Done. Check Sidekiq for progress.'
  end
end
