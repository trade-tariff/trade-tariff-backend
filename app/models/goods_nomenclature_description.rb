class GoodsNomenclatureDescription < Sequel::Model
  include Formatter

  plugin :time_machine
  plugin :oplog, primary_key: %i[goods_nomenclature_sid
                                 goods_nomenclature_description_period_sid]

  set_primary_key %i[goods_nomenclature_sid goods_nomenclature_description_period_sid]

  one_to_one :goods_nomenclature, primary_key: :goods_nomenclature_sid, key: :goods_nomenclature_sid

  one_to_one :goods_nomenclature_description_period, primary_key: %i[goods_nomenclature_description_period_sid goods_nomenclature_sid],
             key: %i[goods_nomenclature_description_period_sid goods_nomenclature_sid]
  
  delegate :validity_start_date, :validity_end_date, to: :goods_nomenclature_description_period
  
  format :description_plain, with: DescriptionTrimFormatter,
         using: :description
  format :formatted_description, with: DescriptionFormatter,
                                 using: :description

  def description
    super.gsub(%r/( ?<br> ?){2,}/, '<br>')
  end

  def formatted_description
    super.mb_chars.downcase.to_s.gsub(/^(.)/) { $1.capitalize }
  end

  def to_s
    description
  end
end
