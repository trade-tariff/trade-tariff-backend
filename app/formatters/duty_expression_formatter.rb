class DutyExpressionFormatter
  class << self
    def prettify(float)
      TradeTariffBackend.number_formatter.number_with_precision(
        float,
        minimum_decimal_points: 2,
        precision: 4,
        strip_insignificant_zeros: true
      )
    end

    def format(opts = {})
      duty_expression_id = opts[:duty_expression_id]
      duty_expression_description = opts[:duty_expression_description]
      duty_expression_abbreviation = opts[:duty_expression_abbreviation]
      duty_amount = opts[:duty_amount]
      monetary_unit = opts[:monetary_unit_abbreviation].presence || opts[:monetary_unit]
      measurement_unit = opts[:measurement_unit]
      measurement_unit_qualifier = opts[:measurement_unit_qualifier]
      measurement_unit_abbreviation = measurement_unit.try :abbreviation,
                                                           measurement_unit_qualifier: measurement_unit_qualifier
      if TradeTariffBackend.currency_conversion_enabled?
        currency = opts[:currency] || TradeTariffBackend.currency
        excise = opts[:excise]

        if !excise && duty_amount.present? && currency.present? && monetary_unit.present? && monetary_unit != currency
          period = MonetaryExchangePeriod.actual.last(parent_monetary_unit_code: 'EUR')
          if period.present?
            rate = MonetaryExchangeRate.last(monetary_exchange_period_sid: period.monetary_exchange_period_sid, child_monetary_unit_code: monetary_unit == 'EUR' ? currency : monetary_unit)
            if rate.present?
              duty_amount = (monetary_unit == 'EUR' ? (rate.exchange_rate * duty_amount.to_d).to_f : (duty_amount.to_d / rate.exchange_rate).to_f).round(2)
              monetary_unit = currency
            end
          end
        end
      end

      output = []
      case duty_expression_id
      when "99"
        output << if opts[:formatted]
                    "<abbr title='#{measurement_unit.description}'>#{measurement_unit_abbreviation}</abbr>"
                  else
                    measurement_unit_abbreviation.to_s
                  end
      when "12", "14", "37", "40", "41", "42", "43", "44", "21", "25", "27", "29"
        if duty_expression_abbreviation.present?
          output << duty_expression_abbreviation
        elsif duty_expression_description.present?
          output << duty_expression_description
        end
      when "02", "04", "15", "17", "19", "20", "36"
        if duty_expression_abbreviation.present?
          output << duty_expression_abbreviation
        elsif duty_expression_description.present?
          output << duty_expression_description
        end
        if duty_amount.present?
          output << if opts[:formatted]
                      html_formatted_duty_expression(duty_amount)
                    else
                      prettify(duty_amount).to_s
                    end
        end
        output << if monetary_unit.present?
                    monetary_unit
                  else
                    "%"
                  end
        if measurement_unit_abbreviation.present?
          output << if opts[:formatted]
                      "/ <abbr title='#{measurement_unit.description}'>#{measurement_unit_abbreviation}</abbr>"
                    else
                      "/ #{measurement_unit_abbreviation}"
                    end
        end
      else
        if duty_amount.present?
          output << if opts[:formatted]
                      html_formatted_duty_expression(duty_amount)
                    else
                      prettify(duty_amount).to_s
                    end
        end
        if duty_expression_abbreviation.present? && !monetary_unit.present?
          output << duty_expression_abbreviation
        elsif duty_expression_description.present? && !monetary_unit.present?
          output << duty_expression_description
        elsif duty_expression_description.blank?
          output << "%"
        end
        if monetary_unit.present?
          output << monetary_unit
        end
        if measurement_unit_abbreviation.present?
          output << if opts[:formatted]
                      "/ <abbr title='#{measurement_unit.description}'>#{measurement_unit_abbreviation}</abbr>"
                    else
                      "/ #{measurement_unit_abbreviation}"
                    end
        end
      end
      output.join(" ").html_safe
    end

    private

    def html_formatted_duty_expression(duty_amount)
      "<span>#{prettify(duty_amount)}</span>"
    end
  end
end
