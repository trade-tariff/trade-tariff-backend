class AdditionalCodeSearchService
  MEASURE_EAGER_LOAD_GRAPH = [
    { goods_nomenclature: :goods_nomenclature_descriptions },
  ].freeze
  ADDITIONAL_CODE_EAGER_LOAD_GRAPH = [:additional_code_descriptions].freeze

  def initialize(attributes)
    @code = attributes[:code]
    @type = attributes[:type]
    @description = attributes[:description]
  end

  def call
    Rails.cache.fetch(cache_key, expires_in: 1.day) do
      Api::V2::AdditionalCodes::AdditionalCodeSerializer.new(presented_additional_codes, options).serializable_hash
    end
  end

  private

  attr_reader :code, :type, :description

  def presented_additional_codes
    Api::V2::AdditionalCodePresenter.wrap(
      applicable_additional_codes,
      applicable_goods_nomenclatures,
    )
  end

  def options
    { include: [:goods_nomenclatures] }
  end

  def applicable_goods_nomenclatures
    return [] if applicable_additional_codes.blank?

    Measure
      .actual
      .where(additional_code_sid: additional_code_sids)
      .where('goods_nomenclature_item_id is not null')
      .order(Sequel.asc(:goods_nomenclature_item_id))
      .distinct(:goods_nomenclature_item_id)
      .eager(MEASURE_EAGER_LOAD_GRAPH)
      .all
      .each_with_object({}) do |measure, acc|
        acc[measure.additional_code_sid] ||= []
        acc[measure.additional_code_sid] << measure.goods_nomenclature if measure.goods_nomenclature.present?
      end
  end

  def additional_code_sids
    applicable_additional_codes.map(&:additional_code_sid)
  end

  def applicable_additional_codes
    return [] unless code_search? || description_search?

    @applicable_additional_codes ||= begin
      candidate_query = if code_search?
                          AdditionalCode.where(additional_code: code, additional_code_type_id: type)
                        elsif description_search?
                          AdditionalCode.where(Sequel.ilike(:description, "%#{description}%"))
                        end

      candidate_query.actual.eager(ADDITIONAL_CODE_EAGER_LOAD_GRAPH).all
    end
  end

  def code_search?
    code.present? && type.present?
  end

  def description_search?
    description.present?
  end

  def cache_key
    content_addressable = additional_code_sids.sort.join

    hash = Digest::MD5.hexdigest(content_addressable)

    "additional_code_search_service/#{hash}"
  end
end
