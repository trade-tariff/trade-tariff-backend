class ValidityPeriodSerializerService
  INCLUDES = %i[deriving_goods_nomenclatures].freeze

  def initialize(params)
    @params = params
  end

  def call
    Api::V2::ValidityPeriodSerializer.new(
      presented_goods_nomenclatures,
      include: INCLUDES,
    ).serializable_hash
  end

  private

  attr_reader :params

  def presented_goods_nomenclatures
    Api::V2::ValidityPeriodPresenter.wrap(goods_nomenclatures_in_all_periods)
  end

  def goods_nomenclatures_in_all_periods
    goods_nomenclature_scope
      .limit(10)
      .eager(deriving_goods_nomenclature_origins: :goods_nomenclature)
      .order(Sequel.desc(:validity_start_date))
      .to_a
  end

  def goods_nomenclature_scope
    if params[:commodity_id].present?
      # TODO: This can include subheadings - e.g. /commodities/0101290000/validity_periods is a subheading
      Commodity.by_code(params[:commodity_id]).declarable
    elsif params[:subheading_id].present?
      code, producline_suffix = params[:subheading_id].split('-')

      Subheading.by_code(code).by_productline_suffix(producline_suffix)
    elsif params[:heading_id].present?
      Heading.by_code("#{params[:heading_id]}000000").non_grouping
    else
      raise Sequel::RecordNotFound
    end
  end
end
