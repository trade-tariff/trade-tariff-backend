# rubocop:disable RSpec/DescribeClass
require 'csv'

RSpec.describe 'self_texts rake tasks' do
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

    let(:embedding) { Array.new(1536) { 0.1 } }
    let(:api_base_url) { 'https://api.openai.com/v1' }

    before do
      EmbeddingService.reset_client!

      stub_request(:post, "#{api_base_url}/embeddings")
        .to_return do |request|
          body = JSON.parse(request.body)
          count = body['input'].size
          data = Array.new(count) { |i| { 'index' => i, 'embedding' => embedding } }
          { status: 200, body: { 'data' => data }.to_json, headers: { 'Content-Type' => 'application/json' } }
        end
    end

    it 'calls the embeddings API for records missing embeddings' do
      create(:goods_nomenclature_self_text, self_text: 'Live horses')

      generate_embeddings

      expect(WebMock).to have_requested(:post, "#{api_base_url}/embeddings").at_least_once
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
