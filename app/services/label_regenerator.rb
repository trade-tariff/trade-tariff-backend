class LabelRegenerator
  class << self
    def call
      load_self_texts
      confirm_regeneration!
      delete_labels
      enqueue_generation
    end

  private

    def load_self_texts
      csv_path = ENV['CSV_PATH']
      SelfTextLookupService.csv_path = csv_path if csv_path.present?
      $stdout.puts "Loading self-texts from #{SelfTextLookupService.csv_path}..."
      ensure_csv_exists!
      SelfTextLookupService.reload!
      $stdout.puts "Loaded #{SelfTextLookupService.count} self-texts"
    end

    def ensure_csv_exists!
      return if File.exist?(SelfTextLookupService.csv_path)

      $stdout.puts "ERROR: Self-texts CSV not found at #{SelfTextLookupService.csv_path}"
      $stdout.puts 'Set CSV_PATH environment variable or place file at data/CN2026_SelfText_EN_DE_FR.csv'
      raise SystemExit.new(1, 'exit')
    end

    def confirm_regeneration!
      return if ENV['CONFIRM'] == 'true'

      $stdout.puts "\nWARNING: This will delete ALL existing labels and regenerate them."
      $stdout.puts 'Set CONFIRM=true to proceed.'
      raise SystemExit.new(1, 'exit')
    end

    def delete_labels
      $stdout.puts "\nDeleting all labels..."
      label_dataset = GoodsNomenclatureLabel.dataset
      deleted_count = label_dataset.count
      PaperTrail::BulkVersioning.record_destroy_versions_for_dataset!(dataset: label_dataset) if deleted_count.positive?
      label_dataset.delete
      $stdout.puts "Deleted #{deleted_count} labels"
      $stdout.puts "\nEnqueuing label generation..."
    end

    def enqueue_generation
      $stdout.puts 'Enqueuing label generation...'
      RelabelGoodsNomenclatureWorker.perform_async
      $stdout.puts 'Done. Check Sidekiq for progress.'
    end
  end
end
