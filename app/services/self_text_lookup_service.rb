require 'csv'

class SelfTextLookupService
  DEFAULT_CSV_PATH = Rails.root.join('data/CN2026_SelfText_EN_DE_FR.csv').freeze

  class << self
    def lookup(goods_nomenclature_item_id)
      self_texts[goods_nomenclature_item_id]
    end

    def self_texts
      @self_texts ||= load_self_texts
    end

    def reload!
      @self_texts = nil
      self_texts
    end

    def csv_path
      @csv_path || DEFAULT_CSV_PATH
    end

    def csv_path=(path)
      @csv_path = path
      @self_texts = nil
    end

    def loaded?
      @self_texts.present?
    end

    def count
      self_texts.size
    end

    private

    def load_self_texts
      path = csv_path

      unless File.exist?(path)
        Rails.logger.warn("SelfTextLookupService: CSV not found at #{path}")
        return {}
      end

      texts = {}
      CSV.foreach(path, headers: true) do |row|
        code = normalize_code(row['CN_CODE'])
        self_text = row['SelfText_EN']&.strip

        next if code.blank?
        next if self_text.blank?

        texts[code] = self_text
      end

      Rails.logger.info("SelfTextLookupService: loaded #{texts.size} self-texts from #{path}")
      texts
    end

    def normalize_code(code)
      return nil if code.blank?

      code.gsub(/\s/, '').ljust(10, '0')
    end
  end
end
