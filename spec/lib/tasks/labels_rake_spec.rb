# rubocop:disable RSpec/DescribeClass
RSpec.describe 'labels tasks' do
  around do |example|
    original_chapter = ENV.fetch('CHAPTER', nil)
    ENV.delete('CHAPTER')
    example.run
  ensure
    original_chapter ? ENV['CHAPTER'] = original_chapter : ENV.delete('CHAPTER')
  end

  describe 'labels:relabel' do
    subject(:relabel) { suppress_output { Rake::Task['labels:relabel'].invoke } }

    after { Rake::Task['labels:relabel'].reenable }

    it 'marks labels stale and records an update version' do
      label = create(:goods_nomenclature_label, stale: false)
      allow(RelabelGoodsNomenclatureWorker).to receive(:perform_async)

      expect { relabel }.to change(Version, :count).by(1)

      expect(label.reload.stale).to be true
      expect(label.versions.order(:id).last.event).to eq('update')
    end
  end

  describe 'labels:gaps' do
    subject(:gaps) { Rake::Task['labels:gaps'].invoke }

    let(:task) { Rake::Task['labels:gaps'] }

    after { task.reenable }

    it 'reports zero totals when there are no declarable commodities' do
      expect { gaps }.to output(/TOTAL\s+0\s+0\s+0\s+0\s+0\s+0\.0%.*No gaps found - full coverage, nothing stale or drifted!/m).to_stdout
    end

    it 'reports the total and missing counts for a chapter with an unlabeled commodity' do
      create(:commodity, goods_nomenclature_item_id: '0101210000')

      expect { gaps }.to output(/01\s+\?\s+1\s+1\s+0\s+0\s+1\s+0\.0%/).to_stdout
    end

    it 'reports mixed gap totals and reasons ordered by commodity code' do
      missing = create(:commodity, goods_nomenclature_item_id: '0101299000')
      drifted = create(:commodity, goods_nomenclature_item_id: '0101291000')
      stale = create(:commodity, goods_nomenclature_item_id: '0101210000')
      current = create(:commodity, goods_nomenclature_item_id: '0101300000')

      create(:goods_nomenclature_label, goods_nomenclature: current)
      create(:goods_nomenclature_label, :stale, goods_nomenclature: stale)
      create(:goods_nomenclature_self_text, goods_nomenclature: drifted, self_text: 'Changed context')
      create(:goods_nomenclature_label, goods_nomenclature: drifted, context_hash: Digest::SHA256.hexdigest('Old context'))

      expect { gaps }.to output(
        /01\s+\?\s+4\s+1\s+1\s+1\s+3\s+75\.0%.*
         TOTAL\s+4\s+1\s+1\s+1\s+3\s+75\.0%.*
         #{stale.goods_nomenclature_item_id}\s+80\s+stale.*
         #{drifted.goods_nomenclature_item_id}\s+80\s+drifted.*
         #{missing.goods_nomenclature_item_id}\s+80\s+missing.*
         Total\s+needing\s+work:\s+3/mx,
      ).to_stdout
    end

    it 'scopes chapter, heading, and commodity output to the requested chapter' do
      included = create(:commodity, goods_nomenclature_item_id: '0101210000')
      excluded = create(:commodity, goods_nomenclature_item_id: '0201290000')
      ENV['CHAPTER'] = '01'

      expected_output = satisfy do |output|
        expect(output).to match(/^01\s+\?\s+1\s+1\s+0\s+0\s+1\s+0\.0%/)
        expect(output).to match(/^-- Chapter 01: \? --$/)
        expect(output).to match(/^\s+0101\s+\?\s+1\s+0\s+0\s+1$/)
        expect(output).to include(included.goods_nomenclature_item_id)
        expect(output).not_to match(/^02\s+/)
        expect(output).not_to include('-- Chapter 02:', '  0201 ', excluded.goods_nomenclature_item_id)
      end

      expect { gaps }.to output(expected_output).to_stdout
    end

    it 'excludes manually edited labels from stale and context-drift work' do
      missing = create(:commodity, goods_nomenclature_item_id: '0101210000')
      manually_stale = create(:commodity, goods_nomenclature_item_id: '0101220000')
      manually_drifted = create(:commodity, goods_nomenclature_item_id: '0101230000')

      create(:goods_nomenclature_label, :stale, :manually_edited, goods_nomenclature: manually_stale)
      create(:goods_nomenclature_self_text, goods_nomenclature: manually_drifted, self_text: 'Changed context')
      create(
        :goods_nomenclature_label,
        :manually_edited,
        goods_nomenclature: manually_drifted,
        context_hash: Digest::SHA256.hexdigest('Old context'),
      )

      expected_output = satisfy do |output|
        expect(output).to match(/^01\s+\?\s+3\s+1\s+0\s+0\s+1\s+66\.7%/)
        expect(output).to match(/^TOTAL\s+3\s+1\s+0\s+0\s+1\s+66\.7%/)
        expect(output).to include(missing.goods_nomenclature_item_id, 'Total needing work: 1')
        expect(output).not_to include(manually_stale.goods_nomenclature_item_id, manually_drifted.goods_nomenclature_item_id)
      end

      expect { gaps }.to output(expected_output).to_stdout
    end
  end

  describe 'labels:nuke_and_regenerate' do
    subject(:nuke_and_regenerate) { task.invoke }

    let(:task) { Rake::Task['labels:nuke_and_regenerate'] }
    let(:temp_dir) { Dir.mktmpdir('labels-rake-spec') }
    let(:csv_path) { File.join(temp_dir, 'self_texts.csv') }
    let(:csv_contents) do
      <<~CSV
        CN_CODE,SelfText_EN
        0101 21 00,Pure-bred breeding horses
        8471300000,Portable digital computers
      CSV
    end

    around do |example|
      original_csv_path_env = ENV.fetch('CSV_PATH', nil)
      original_confirm_env = ENV.fetch('CONFIRM', nil)
      csv_path_was_defined = SelfTextLookupService.instance_variable_defined?(:@csv_path)
      self_texts_were_defined = SelfTextLookupService.instance_variable_defined?(:@self_texts)
      original_csv_path = SelfTextLookupService.instance_variable_get(:@csv_path)
      original_self_texts = SelfTextLookupService.instance_variable_get(:@self_texts)

      example.run
    ensure
      task.reenable
      FileUtils.remove_entry(temp_dir) if File.exist?(temp_dir)
      original_csv_path_env ? ENV['CSV_PATH'] = original_csv_path_env : ENV.delete('CSV_PATH')
      original_confirm_env ? ENV['CONFIRM'] = original_confirm_env : ENV.delete('CONFIRM')

      if csv_path_was_defined
        SelfTextLookupService.instance_variable_set(:@csv_path, original_csv_path)
      elsif SelfTextLookupService.instance_variable_defined?(:@csv_path)
        SelfTextLookupService.remove_instance_variable(:@csv_path)
      end

      if self_texts_were_defined
        SelfTextLookupService.instance_variable_set(:@self_texts, original_self_texts)
      elsif SelfTextLookupService.instance_variable_defined?(:@self_texts)
        SelfTextLookupService.remove_instance_variable(:@self_texts)
      end
    end

    before do
      ENV['CSV_PATH'] = csv_path
      ENV.delete('CONFIRM')
      allow(RelabelGoodsNomenclatureWorker).to receive(:perform_async).with(no_args)
      allow(PaperTrail::BulkVersioning).to receive(:record_destroy_versions_for_dataset!).and_call_original
    end

    context 'when the CSV is missing' do
      it 'exits before reloading, deleting, versioning, or enqueuing' do
        label = create(:goods_nomenclature_label)
        version_count = Version.count
        allow(SelfTextLookupService).to receive(:reload!).and_call_original

        expected_output = <<~OUTPUT
          Loading self-texts from #{csv_path}...
          ERROR: Self-texts CSV not found at #{csv_path}
          Set CSV_PATH environment variable or place file at data/CN2026_SelfText_EN_DE_FR.csv
        OUTPUT
        exit_with_status_one = raise_error(SystemExit) do |error|
          expect(error.status).to eq(1)
        end

        expect { nuke_and_regenerate }
          .to output(expected_output).to_stdout
          .and exit_with_status_one

        expect(SelfTextLookupService).not_to have_received(:reload!)
        expect(GoodsNomenclatureLabel[label.goods_nomenclature_sid]).to be_present
        expect(Version.count).to eq(version_count)
        expect(PaperTrail::BulkVersioning).not_to have_received(:record_destroy_versions_for_dataset!)
        expect(RelabelGoodsNomenclatureWorker).not_to have_received(:perform_async)
      end
    end

    context 'when confirmation is not exactly true' do
      before do
        File.write(csv_path, csv_contents)
        ENV['CONFIRM'] = confirmation if confirmation
      end

      shared_examples 'rejected regeneration' do
        it 'loads the CSV, warns, and exits without changing labels or enqueuing' do
          label = create(:goods_nomenclature_label)
          version_count = Version.count

          expected_output = <<~OUTPUT
            Loading self-texts from #{csv_path}...
            Loaded 2 self-texts

            WARNING: This will delete ALL existing labels and regenerate them.
            Set CONFIRM=true to proceed.
          OUTPUT
          exit_with_status_one = raise_error(SystemExit) do |error|
            expect(error.status).to eq(1)
          end

          expect { nuke_and_regenerate }
            .to output(expected_output).to_stdout
            .and exit_with_status_one

          expect(SelfTextLookupService.count).to eq(2)
          expect(SelfTextLookupService.lookup('0101210000')).to eq('Pure-bred breeding horses')
          expect(GoodsNomenclatureLabel[label.goods_nomenclature_sid]).to be_present
          expect(Version.count).to eq(version_count)
          expect(PaperTrail::BulkVersioning).not_to have_received(:record_destroy_versions_for_dataset!)
          expect(RelabelGoodsNomenclatureWorker).not_to have_received(:perform_async)
        end
      end

      context 'when confirmation is missing' do
        let(:confirmation) { nil }

        include_examples 'rejected regeneration'
      end

      context "when confirmation is 'false'" do
        let(:confirmation) { 'false' }

        include_examples 'rejected regeneration'
      end
    end

    context 'when regeneration is confirmed' do
      before do
        File.write(csv_path, csv_contents)
        ENV['CONFIRM'] = 'true'
      end

      it 'versions every label before deleting it, then enqueues generation' do
        labels = [
          create(:goods_nomenclature_label, goods_nomenclature_item_id: '0101210000'),
          create(:goods_nomenclature_label, goods_nomenclature_item_id: '8471300000'),
        ]
        label_item_ids = labels.map { |label| label.goods_nomenclature_sid.to_s }
        events = []

        allow(PaperTrail::BulkVersioning).to receive(:record_destroy_versions_for_dataset!).and_wrap_original do |method, dataset:|
          events << [:version, dataset.select_map(:goods_nomenclature_sid).map(&:to_s)]
          method.call(dataset:)
        end
        allow(RelabelGoodsNomenclatureWorker).to receive(:perform_async).with(no_args) do
          destroy_version_item_ids = Version.where(item_type: 'GoodsNomenclatureLabel', event: 'destroy').select_map(:item_id)
          events << [:enqueue, GoodsNomenclatureLabel.count, destroy_version_item_ids]
        end

        expect { nuke_and_regenerate }.to output(<<~OUTPUT).to_stdout
          Loading self-texts from #{csv_path}...
          Loaded 2 self-texts

          Deleting all labels...
          Deleted 2 labels

          Enqueuing label generation...
          Enqueuing label generation...
          Done. Check Sidekiq for progress.
        OUTPUT

        expect(events.map(&:first)).to eq(%i[version enqueue])
        expect(events.first.second).to match_array(label_item_ids)
        expect(events.second.second).to be_zero
        expect(events.second.third).to match_array(label_item_ids)
        expect(GoodsNomenclatureLabel.count).to be_zero
        expect(RelabelGoodsNomenclatureWorker).to have_received(:perform_async).with(no_args).once
      end

      it 'skips destroy versioning with no labels but still reports zero and enqueues' do
        destroy_version_count = Version.where(item_type: 'GoodsNomenclatureLabel', event: 'destroy').count

        expect { nuke_and_regenerate }.to output(<<~OUTPUT).to_stdout
          Loading self-texts from #{csv_path}...
          Loaded 2 self-texts

          Deleting all labels...
          Deleted 0 labels

          Enqueuing label generation...
          Enqueuing label generation...
          Done. Check Sidekiq for progress.
        OUTPUT

        expect(Version.where(item_type: 'GoodsNomenclatureLabel', event: 'destroy').count).to eq(destroy_version_count)
        expect(PaperTrail::BulkVersioning).not_to have_received(:record_destroy_versions_for_dataset!)
        expect(RelabelGoodsNomenclatureWorker).to have_received(:perform_async).with(no_args).once
      end
    end
  end
end
# rubocop:enable RSpec/DescribeClass
