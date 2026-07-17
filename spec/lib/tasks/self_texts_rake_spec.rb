# rubocop:disable RSpec/DescribeClass
require 'csv'

RSpec.describe 'self_texts rake tasks' do
  describe 'self_texts:coverage' do
    subject(:coverage) { Rake::Task['self_texts:coverage'].invoke }

    after { Rake::Task['self_texts:coverage'].reenable }

    it 'reports coverage, stale records, and generation-type counts' do
      create(:chapter)
      generated = create(:commodity)
      stale = create(:commodity)
      create(:commodity)
      create(:goods_nomenclature_self_text,
             goods_nomenclature: generated,
             generation_type: 'mechanical')
      create(:goods_nomenclature_self_text,
             :stale,
             goods_nomenclature: stale,
             generation_type: 'ai')

      expect { coverage }.to output(<<~OUTPUT).to_stdout
        Self-Text Coverage Statistics
        ------------------------------
        Total GN (excl. chapters): 3
        With self-text:            2
        Missing:                   1
        Coverage:                  66.67%
        Stale:                     1
        Needing work:              2

        By generation type:
          ai: 1
          mechanical: 1
      OUTPUT
    end

    it 'reports zero coverage when there are no goods nomenclatures' do
      expect { coverage }.to output(<<~OUTPUT).to_stdout
        Self-Text Coverage Statistics
        ------------------------------
        Total GN (excl. chapters): 0
        With self-text:            0
        Missing:                   0
        Coverage:                  0%
        Stale:                     0
        Needing work:              0

        By generation type:
      OUTPUT
    end
  end

  describe 'self_texts:regenerate' do
    subject(:regenerate) { Rake::Task['self_texts:regenerate'].invoke }

    after { Rake::Task['self_texts:regenerate'].reenable }

    it 'marks unedited non-stale self-texts stale, versions them, and enqueues regeneration' do
      eligible = create_list(:goods_nomenclature_self_text, 2)
      eligible << create(:goods_nomenclature_self_text, :expired)
      manually_edited = create(:goods_nomenclature_self_text, :manually_edited)
      already_stale = create(:goods_nomenclature_self_text, :stale)
      allow(GenerateSelfTextWorker).to receive(:perform_async) do
        eligible.each do |record|
          version = record.refresh.versions.order(:id).last
          expect(record.stale).to be(true)
          expect(version).to have_attributes(event: 'update')
          expect(version.object['stale']).to be(true)
        end
      end

      expect { regenerate }
        .to output(<<~OUTPUT).to_stdout
          Marked 3 self-texts as stale.
          Enqueued regeneration. Check Sidekiq for progress.
        OUTPUT
        .and change(Version, :count).by(3)

      expect(eligible.map { |record| record.refresh.stale }).to all(be(true))
      expect(eligible.last.expired).to be(true)
      expect(manually_edited.refresh.stale).to be(false)
      expect(already_stale.refresh.stale).to be(true)
      expect(GenerateSelfTextWorker).to have_received(:perform_async).with(no_args).once
    end

    it 'still enqueues regeneration without creating versions when no records change' do
      create(:goods_nomenclature_self_text, :manually_edited)
      create(:goods_nomenclature_self_text, :stale)
      allow(GenerateSelfTextWorker).to receive(:perform_async)
      version_count = Version.count

      expect { regenerate }
        .to output(<<~OUTPUT).to_stdout
          Marked 0 self-texts as stale.
          Enqueued regeneration. Check Sidekiq for progress.
        OUTPUT

      expect(Version.count).to eq(version_count)
      expect(GenerateSelfTextWorker).to have_received(:perform_async).with(no_args).once
    end
  end

  describe 'self_texts:generate' do
    subject(:generate) { Rake::Task['self_texts:generate'].invoke }

    let(:task) { Rake::Task['self_texts:generate'] }
    let!(:original_chapter) { ENV.fetch('CHAPTER', nil) }

    before do
      allow(GenerateSelfTextWorker).to receive(:perform_async)
      allow(GenerateSelfText::OtherSelfTextBuilder).to receive(:call)
      allow(GenerateSelfText::NonOtherSelfTextBuilder).to receive(:call)
    end

    after do
      task.reenable
      original_chapter ? ENV['CHAPTER'] = original_chapter : ENV.delete('CHAPTER')
    end

    context 'without a chapter code' do
      before { ENV.delete('CHAPTER') }

      it 'enqueues generation for all chapters' do
        expect { generate }.to output(<<~OUTPUT).to_stdout
          Enqueuing self-text generation for all chapters...
          Done. Check Sidekiq for progress.
        OUTPUT

        expect(GenerateSelfTextWorker).to have_received(:perform_async).once
        expect(GenerateSelfTextWorker).to have_received(:perform_async).with(no_args).once
        expect(GenerateSelfText::OtherSelfTextBuilder).not_to have_received(:call)
        expect(GenerateSelfText::NonOtherSelfTextBuilder).not_to have_received(:call)
      end
    end

    context 'with an existing chapter code' do
      let(:chapter_code) { '42' }
      let!(:chapter) { create(:chapter, goods_nomenclature_item_id: '4200000000') }
      let!(:expired_chapter) do
        create(:chapter, :expired, goods_nomenclature_item_id: '4200000000')
      end
      let(:other_result) { { processed: 2, failed: 0 } }
      let(:non_other_result) { { processed: 3, failed: 0 } }

      before do
        ENV['CHAPTER'] = chapter_code
        allow(GenerateSelfText::OtherSelfTextBuilder).to receive(:call).and_return(other_result)
        allow(GenerateSelfText::NonOtherSelfTextBuilder).to receive(:call).and_return(non_other_result)
      end

      it 'generates both kinds of self-text inline for the actual chapter' do
        expect { generate }.to output(<<~OUTPUT).to_stdout
          Generating self-texts for chapter 42...
          Other AI: #{other_result.inspect}
          Non-Other AI: #{non_other_result.inspect}
        OUTPUT

        expect(GenerateSelfText::OtherSelfTextBuilder).to have_received(:call).with(chapter).once.ordered
        expect(GenerateSelfText::NonOtherSelfTextBuilder).to have_received(:call).with(chapter).once.ordered
        expect(GenerateSelfText::OtherSelfTextBuilder).to have_received(:call).once
        expect(GenerateSelfText::NonOtherSelfTextBuilder).to have_received(:call).once
        expect(GenerateSelfText::OtherSelfTextBuilder).not_to have_received(:call).with(expired_chapter)
        expect(GenerateSelfText::NonOtherSelfTextBuilder).not_to have_received(:call).with(expired_chapter)
        expect(GenerateSelfTextWorker).not_to have_received(:perform_async)
      end
    end

    context 'with a missing chapter code' do
      before { ENV['CHAPTER'] = '98' }

      it 'raises before generating or enqueuing self-texts' do
        expect { generate }
          .to output('').to_stdout
          .and raise_error(Sequel::RecordNotFound)

        expect(GenerateSelfText::OtherSelfTextBuilder).not_to have_received(:call)
        expect(GenerateSelfText::NonOtherSelfTextBuilder).not_to have_received(:call)
        expect(GenerateSelfTextWorker).not_to have_received(:perform_async)
      end
    end
  end

  describe 'self_texts:populate_eu_references' do
    subject(:populate) do
      suppress_output { Rake::Task['self_texts:populate_eu_references'].invoke }
    end

    after do
      Rake::Task['self_texts:populate_eu_references'].reenable
      FileUtils.rm_f(csv_path)
    end

    let(:csv_path) { Rails.root.join('tmp/test_self_texts.csv') }
    let(:stored_embedding) { Sequel.lit("'[#{Array.new(1536, 0.1).join(',')}]'::vector") }

    before do
      FileUtils.rm_f(csv_path)
      stub_const('SelfTextLookupService::DEFAULT_CSV_PATH', csv_path)
      # Override the hardcoded CSV path in the rake task by stubbing Rails.root.join
      allow(Rails.root).to receive(:join)
        .with('data/CN2026_SelfText_EN_DE_FR.csv')
        .and_return(csv_path)
    end

    context 'when CSV has matching records' do
      before do
        create(:goods_nomenclature_self_text,
               goods_nomenclature_item_id: '0101210000',
               self_text: 'Pure-bred breeding horses')

        CSV.open(csv_path, 'w', headers: true) do |csv|
          csv << %w[CNKEY CN_CODE NAME_EN SelfText_EN NAME_DE SelfText_DE NAME_FR SelfText_FR]
          csv << ['010121000080',
                  '0101 21 00',
                  'Pure-bred breeding animals',
                  'Pure-bred breeding horses',
                  '',
                  '',
                  '',
                  '']
        end
      end

      after { FileUtils.rm_f(csv_path) }

      it 'updates the eu_self_text column' do
        populate

        record = GoodsNomenclatureSelfText.where(goods_nomenclature_item_id: '0101210000').first
        expect(record.eu_self_text).to eq('Pure-bred breeding horses')
      end
    end

    context 'when an existing EU reference differs' do
      before do
        CSV.open(csv_path, 'w', headers: true) do |csv|
          csv << %w[CNKEY CN_CODE NAME_EN SelfText_EN NAME_DE SelfText_DE NAME_FR SelfText_FR]
          csv << ['010121000080', '0101 21 00', 'Pure-bred', 'Updated EU reference', '', '', '', '']
        end
      end

      it 'updates the reference, clears its embedding, and records an update version' do
        record = create(:goods_nomenclature_self_text,
                        goods_nomenclature_item_id: '0101210000',
                        eu_self_text: 'Old EU reference',
                        eu_embedding: stored_embedding)
        version_count = record.versions.count

        populate

        expect(record.reload).to have_attributes(eu_self_text: 'Updated EU reference', eu_embedding: nil)
        expect(record.versions.count).to eq(version_count + 1)
        expect(record.versions.order(:id).last.event).to eq('update')
      end
    end

    context 'when an existing EU reference is identical' do
      before do
        CSV.open(csv_path, 'w', headers: true) do |csv|
          csv << %w[CNKEY CN_CODE NAME_EN SelfText_EN NAME_DE SelfText_DE NAME_FR SelfText_FR]
          csv << ['010121000080', '0101 21 00', 'Pure-bred', 'Existing EU reference', '', '', '', '']
        end
      end

      it 'preserves the reference, embedding, and version history' do
        record = create(:goods_nomenclature_self_text,
                        goods_nomenclature_item_id: '0101210000',
                        eu_self_text: 'Existing EU reference',
                        eu_embedding: stored_embedding)
        embedding = record.reload.eu_embedding
        version_count = record.versions.count

        populate

        expect(record.reload).to have_attributes(eu_self_text: 'Existing EU reference', eu_embedding: embedding)
        expect(record.versions.count).to eq(version_count)
      end
    end

    context 'when CSV has no matching generated text' do
      before do
        CSV.open(csv_path, 'w', headers: true) do |csv|
          csv << %w[CNKEY CN_CODE NAME_EN SelfText_EN NAME_DE SelfText_DE NAME_FR SelfText_FR]
          csv << ['999999000080', '9999 99 00', 'Nonexistent', 'Nonexistent item', '', '', '', '']
        end
      end

      after { FileUtils.rm_f(csv_path) }

      it 'does not create new records' do
        expect { populate }.not_to change(GoodsNomenclatureSelfText, :count)
      end
    end

    context 'when CSV has blank self-text' do
      before do
        create(:goods_nomenclature_self_text,
               goods_nomenclature_item_id: '0101300000')

        CSV.open(csv_path, 'w', headers: true) do |csv|
          csv << %w[CNKEY CN_CODE NAME_EN SelfText_EN NAME_DE SelfText_DE NAME_FR SelfText_FR]
          csv << ['010130000080', '0101 30 00', 'Asses', '', '', '', '', '']
        end
      end

      after { FileUtils.rm_f(csv_path) }

      it 'skips rows with blank SelfText_EN' do
        populate

        record = GoodsNomenclatureSelfText.where(goods_nomenclature_item_id: '0101300000').first
        expect(record.eu_self_text).to be_nil
      end
    end

    context 'when the CSV is missing' do
      it 'prints its path and exits with status 1' do
        expect { Rake::Task['self_texts:populate_eu_references'].invoke }
          .to output("CSV not found at #{csv_path}\n").to_stdout
          .and raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      end
    end

    context 'when the CSV contains updated, unmatched, and blank rows' do
      before do
        create(:goods_nomenclature_self_text,
               goods_nomenclature_item_id: '0101210000',
               eu_self_text: 'Old EU reference')

        CSV.open(csv_path, 'w', headers: true) do |csv|
          csv << %w[CNKEY CN_CODE NAME_EN SelfText_EN NAME_DE SelfText_DE NAME_FR SelfText_FR]
          csv << ['010121000080', '0101 21 00', 'Pure-bred', 'Updated EU reference', '', '', '', '']
          csv << ['999999000080', '9999 99 00', 'Nonexistent', 'No matching text', '', '', '', '']
          csv << ['010130000080', '0101 30 00', 'Asses', '', '', '', '', '']
        end
      end

      it 'reports each completion count' do
        expect { Rake::Task['self_texts:populate_eu_references'].invoke }
          .to output("EU references populated: 1 updated, 1 no matching generated text, 1 blank\n").to_stdout
      end
    end

    context 'when run twice with same data (idempotent)' do
      before do
        create(:goods_nomenclature_self_text,
               goods_nomenclature_item_id: '0101210000')

        CSV.open(csv_path, 'w', headers: true) do |csv|
          csv << %w[CNKEY CN_CODE NAME_EN SelfText_EN NAME_DE SelfText_DE NAME_FR SelfText_FR]
          csv << ['010121000080', '0101 21 00', 'Pure-bred', 'Pure-bred breeding horses', '', '', '', '']
        end
      end

      after { FileUtils.rm_f(csv_path) }

      it 'does not change records on second run' do
        populate
        Rake::Task['self_texts:populate_eu_references'].reenable

        record_before = GoodsNomenclatureSelfText.where(goods_nomenclature_item_id: '0101210000').first
        suppress_output { Rake::Task['self_texts:populate_eu_references'].invoke }
        record_after = GoodsNomenclatureSelfText.where(goods_nomenclature_item_id: '0101210000').first

        expect(record_after.eu_self_text).to eq(record_before.eu_self_text)
      end
    end
  end

  describe 'self_texts:generate_embeddings' do
    subject(:generate_embeddings) do
      suppress_output { Rake::Task['self_texts:generate_embeddings'].invoke }
    end

    after { Rake::Task['self_texts:generate_embeddings'].reenable }

    let(:embedding_for) { ->(text) { Array.new(1536) { text.length / 100.0 } } }
    let(:embedding) { embedding_for.call('Live horses') }
    let(:api_base_url) { 'https://api.openai.com/v1' }

    before do
      EmbeddingService.reset_client!

      stub_request(:post, "#{api_base_url}/embeddings")
        .to_return do |request|
          body = JSON.parse(request.body)
          data = body['input'].each_with_index.map do |text, index|
            { 'index' => index, 'embedding' => embedding_for.call(text) }
          end
          { status: 200, body: { 'data' => data }.to_json, headers: { 'Content-Type' => 'application/json' } }
        end
    end

    it 'calls the embeddings API for records missing embeddings' do
      create(:goods_nomenclature_self_text, self_text: 'Live horses')

      generate_embeddings

      expect(WebMock).to have_requested(:post, "#{api_base_url}/embeddings").at_least_once
    end

    it 'persists generated and EU embeddings and versions each update' do
      record = create(:goods_nomenclature_self_text,
                      self_text: 'Live horses',
                      eu_self_text: 'EU live horses')
      version_count = record.versions.count

      generate_embeddings

      expect(record.reload.embedding).to eq(embedding_for.call('Live horses').to_json)
      expect(record.eu_embedding).to eq(embedding_for.call('EU live horses').to_json)
      expect(record.versions.count).to eq(version_count + 2)
      expect(record.versions.order(:id).last(2).map(&:event)).to eq(%w[update update])
    end

    it 'preserves existing embeddings and version history' do
      stored_embedding = Sequel.lit("'[#{embedding.join(',')}]'::vector")
      record = create(:goods_nomenclature_self_text,
                      self_text: 'Live horses',
                      eu_self_text: 'EU live horses',
                      embedding: stored_embedding,
                      eu_embedding: stored_embedding)
      record.reload
      generated_embedding = record.embedding
      eu_embedding = record.eu_embedding
      version_count = record.versions.count

      generate_embeddings

      expect(WebMock).not_to have_requested(:post, "#{api_base_url}/embeddings")
      expect(record.reload).to have_attributes(embedding: generated_embedding, eu_embedding: eu_embedding)
      expect(record.versions.count).to eq(version_count)
    end

    it 'processes generated embeddings in batches and reports progress' do
      stub_const('EmbeddingService::BATCH_SIZE', 2)
      records = ['Batch one', 'Second batch record', 'Final record'].map do |text|
        create(:goods_nomenclature_self_text, self_text: text, eu_self_text: nil)
      end

      expect { Rake::Task['self_texts:generate_embeddings'].invoke }
        .to output(/Generated: 2\/3 embedded.*Generated: 3\/3 embedded/m).to_stdout
      expect(WebMock).to have_requested(:post, "#{api_base_url}/embeddings").twice
      expect(records.map { |record| record.reload.embedding }).to eq(
        records.map { |record| embedding_for.call(record.self_text).to_json },
      )
    end

    it 'instruments generated and EU embedding backfill batches with event kinds' do
      create(:goods_nomenclature_self_text, self_text: 'Live horses')
      create(:goods_nomenclature_self_text, self_text: 'Pure-bred horses', eu_self_text: 'EU pure-bred horses')
      events = []
      subscriber = ActiveSupport::Notifications.subscribe('embedding_api_call_completed.ai_usage') do |*args|
        events << ActiveSupport::Notifications::Event.new(*args)
      end

      generate_embeddings

      expect(events.map { |event| event.payload[:event_kind] }).to include(
        'self_text_embedding_backfill',
        'eu_self_text_embedding_backfill',
      )
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end
  end
end
# rubocop:enable RSpec/DescribeClass
