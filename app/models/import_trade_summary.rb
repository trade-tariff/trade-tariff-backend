class ImportTradeSummary
  include ContentAddressableId

  attr_accessor :import_measures

  content_addressable_fields :basic_third_country_duty,
                             :preferential_tariff_duty,
                             :preferential_quota_duty

  def self.build(import_measures)
    trade_summary = new

    trade_summary.import_measures = import_measures

    trade_summary
  end

  def basic_third_country_duty
    if third_country_measures.one?
      third_country_measures.first.formatted_duty_expression
    end
  end

  def preferential_tariff_duty
    if tariff_preference_measures.one?
      tariff_preference_measures.first.formatted_duty_expression
    end
  end

  def preferential_quota_duty
    if preferential_quota_measures.one?
      preferential_quota_measures.first.formatted_duty_expression
    end
  end

  private

  def third_country_measures
    @third_country_measures ||= import_measures
                                  .select(&:third_country?)
                                  .select(&:erga_omnes?)
  end

  def tariff_preference_measures
    @tariff_preference_measures ||= import_measures.select(&:tariff_preference?)
  end

  def preferential_quota_measures
    @preferential_quota_measures ||= import_measures.select(&:preferential_quota?)
  end
end
