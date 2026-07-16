require 'csv'

class EuReferenceSelfTextImporter
  def self.call(csv_path)
    new(csv_path).call
  end

  def initialize(csv_path)
    @csv_path = csv_path
  end

  def call
    missing_csv! unless File.exist?(@csv_path)

    stats = { updated: 0, skipped_no_match: 0, skipped_blank: 0 }
    CSV.foreach(@csv_path, headers: true) { |row| populate_eu_reference(row, stats) }
    $stdout.puts "EU references populated: #{stats[:updated]} updated, #{stats[:skipped_no_match]} no matching generated text, #{stats[:skipped_blank]} blank"
  end

private

  def missing_csv!
    $stdout.puts "CSV not found at #{@csv_path}"
    raise SystemExit.new(1, 'exit')
  end

  def populate_eu_reference(row, stats)
    code = row['CN_CODE']
    eu_text = row['SelfText_EN']&.strip

    return stats[:skipped_blank] += 1 if code.blank? || eu_text.blank?

    normalized = code.gsub(/\s/, '').ljust(10, '0')
    dataset = update_dataset(normalized, eu_text)
    item_ids = dataset.select_map(:goods_nomenclature_sid)
    count = dataset.update(eu_self_text: eu_text, eu_embedding: nil)
    PaperTrail::BulkVersioning.record_current_versions_for_item_ids!(model: GoodsNomenclatureSelfText, item_ids:) if count.positive?
    update_stats(stats, normalized, count)
  end

  def update_dataset(normalized, eu_text)
    GoodsNomenclatureSelfText
      .where(goods_nomenclature_item_id: normalized)
      .where(Sequel.|({ eu_self_text: nil }, Sequel.~(eu_self_text: eu_text)))
  end

  def update_stats(stats, normalized, count)
    if count.positive?
      stats[:updated] += count
    else
      existing = GoodsNomenclatureSelfText.where(goods_nomenclature_item_id: normalized).count
      stats[:skipped_no_match] += 1 if existing.zero?
    end
  end
end
