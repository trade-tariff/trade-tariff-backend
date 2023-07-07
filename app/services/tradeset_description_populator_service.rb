require 'tariff_synchronizer/file_service'

class TradesetDescriptionPopulatorService
  FILENAME_REGEX = /\A(?<month>[a-zA-Z]+)(?<year>\d+).*\z/
  CHUNK_SIZE = 5000
  ENCODINGS = [
    'Windows-1252:UTF-8',
    'UTF-16LE:BOM|UTF-8',
    'ISO-8859-1:UTF-8',
  ].freeze

  def call
    each_tradeset_descriptions_chunk do |chunk|
      upsert_chunk(chunk)
    end
  end

  private

  def upsert_chunk(chunk)
    TradesetDescription.dataset.insert_conflict(
      constraint: :tradeset_descriptions_filename_description_goods_nomenclatu_key,
      update: { updated_at: Sequel::CURRENT_TIMESTAMP },
    ).multi_insert(chunk.uniq)
  end

  def each_tradeset_descriptions_chunk
    csv = CSV.open(file_path, headers: true, header_converters: :symbol, encoding:)
    created_at = Time.zone.now.utc
    updated_at = created_at

    chunk = []

    csv.each do |row|
      attributes = row.to_hash
      attributes[:classification_date] = classification_date
      attributes[:filename] = filename
      attributes[:created_at] = created_at
      attributes[:updated_at] = updated_at

      tradeset_description = TradesetDescription.build(attributes)

      unless chunk.size >= CHUNK_SIZE
        chunk << tradeset_description if tradeset_description.valid?

        next
      end

      yield chunk

      chunk = []
    end

    yield chunk unless chunk.empty?
  ensure
    csv&.close
  end

  def filename
    File.basename(file_path)
  end

  def file_path
    @file_path ||= download_latest_csv_file.first
  end

  def encoding
    @encoding ||= ENCODINGS.find do |encoding|
      sample = File.read(file_path, encoding:, lines: 5)
      sample.valid_encoding?
    end
  end

  def classification_date
    @classification_date ||= filename.match(FILENAME_REGEX) do |match|
      month = match[:month]
      year = match[:year]
      Date.parse("1 #{month} #{year}").end_of_month
    end
  end

  def download_latest_csv_file
    source = latest_csv_file_path
    destination = Rails.root.join('data/tradeset_descriptions/', File.basename(source))

    TariffSynchronizer::FileService.download_and_unzip(source:, destination:)
  end

  def latest_csv_file_path
    @latest_csv_file_path ||= TariffSynchronizer::FileService.list_by(prefix: 'data/tradeset_descriptions/').last[:path]
  end
end
