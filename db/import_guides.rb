module ImportGuides
  CSV_HEADER = %w[id title image url strapline].freeze

  def self.seed_guides
    file = Rails.root.join('data/guides.csv')

    csv = CSV.open(file, headers: true).read

    if csv.headers != CSV_HEADER
      raise "The header of the CSV does not match with: #{CSV_HEADER}"
    end

    Rails.logger.debug 'Remove existing guides ...'
    Sequel::Model.db[:guides].delete
    Sequel::Model.db[:guides_goods_nomenclatures].delete

    Rails.logger.debug 'Insert in progress ...'

    Guide.unrestrict_primary_key

    CSV.foreach(file, headers: true) do |row|
      Guide.insert(row.to_hash)
      Rails.logger.debug "Added guide #{row['id']}: #{row['title']}"
    end

    seed_guides_chapters
    seed_guides_headings
  end

  def self.seed_guides_chapters
    file = Rails.root.join('data/chapters_guides.csv')

    Rails.logger.debug 'Populating relationship Chapters <-> Guides ...'

    CSV.foreach(file, headers: true) do |row|
      goods_nomenclature_sid = row[5].to_i
      guide_id = row[3].to_i
      chapter_code = row[0]

      GuidesGoodsNomenclature.insert(guide_id:, goods_nomenclature_sid:)

      Rails.logger.debug "Added #{chapter_code}->#{guide_id}"
    end
  end

  def self.seed_guides_headings
    file = Rails.root.join('data/headings_guides.csv')

    Rails.logger.debug 'Populating relationship Headings <-> Guides ...'
    CSV.foreach(file, headers: true) do |row|
      goods_nomenclature_sid = row[5].to_i
      guide_id = row[3].to_i
      heading_code = row[0]

      GuidesGoodsNomenclature.insert(guide_id:, goods_nomenclature_sid:)

      Rails.logger.debug "Added #{heading_code}->#{guide_id}"
    end
  end
end
