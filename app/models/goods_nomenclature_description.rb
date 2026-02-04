class GoodsNomenclatureDescription < Sequel::Model
  CONSIGNED_FROM_REGEX = /consigned from(?: or originating in)?([\p{L},'\s]+)(?:\W|$)/i

  include Formatter

  plugin :time_machine
  plugin :oplog, primary_key: %i[goods_nomenclature_sid
                                 goods_nomenclature_description_period_sid]

  set_primary_key %i[goods_nomenclature_sid goods_nomenclature_description_period_sid]

  one_to_one :goods_nomenclature, primary_key: :goods_nomenclature_sid, key: :goods_nomenclature_sid

  one_to_one :goods_nomenclature_description_period, primary_key: %i[goods_nomenclature_description_period_sid goods_nomenclature_sid],
                                                     key: %i[goods_nomenclature_description_period_sid goods_nomenclature_sid]

  delegate :validity_start_date, :validity_end_date, to: :goods_nomenclature_description_period

  custom_format :description_plain, with: DescriptionTrimFormatter,
                                    using: :description
  custom_format :formatted_description, with: DescriptionFormatter,
                                        using: :description

  custom_format :csv_formatted_description, with: CsvDescriptionFormatter,
                                            using: :formatted_description

  custom_format :description_indexed, with: DescriptionFormatter,
                                      using: :description
  def description
    super.try(:gsub, %r/( ?<br> ?){2,}/, '<br>') || ''
  end

  def description_indexed
    SearchNegationService.new(description.downcase).call
  end

  def description_plain
    super.capitalize
  end

  def formatted_description
    formatted = super.downcase.gsub(/^(.)/) { Regexp.last_match(1).capitalize }
    consigned_countries.each do |country|
      formatted.gsub!(country.downcase, country)
    end
    formatted
  end

  def consigned_countries
    description.scan(CONSIGNED_FROM_REGEX).flatten
  end

  def to_s
    description
  end

  def consigned_from
    consigned_countries = description.scan(CONSIGNED_FROM_REGEX)

    if consigned_countries.present?
      consigned_countries
        .flatten
        .map(&:strip)
        .join(', ')
    end
  end
end
