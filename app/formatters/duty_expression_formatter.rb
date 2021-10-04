class DutyExpressionFormatter
  class << self
    def prettify(float)
      TradeTariffBackend.number_formatter.number_with_precision(
        float,
        minimum_decimal_points: 2,
        precision: 4,
        strip_insignificant_zeros: true,
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
      resolved_meursing_component = opts[:resolved_meursing]
      formatted = opts[:formatted]

      output = []
      case duty_expression_id
      when '99'
        output << if formatted
                    "<abbr title='#{measurement_unit.description}'>#{measurement_unit_abbreviation}</abbr>"
                  else
                    measurement_unit_abbreviation.to_s
                  end
      when '12', '14', '37', '40', '41', '42', '43', '44', '21', '25', '27', '29'
        if duty_expression_abbreviation.present?
          output << duty_expression_abbreviation
        elsif duty_expression_description.present?
          output << duty_expression_description
        end
      when '02', '04', '15', '17', '19', '20', '36'
        if duty_expression_abbreviation.present?
          output << duty_expression_abbreviation
        elsif duty_expression_description.present?
          output << duty_expression_description
        end
        if duty_amount.present?
          output << if formatted
                      html_formatted_duty_expression(duty_amount)
                    else
                      prettify(duty_amount).to_s
                    end
        end
        output << if monetary_unit.present?
                    monetary_unit
                  else
                    '%'
                  end
        if measurement_unit_abbreviation.present?
          output << if formatted
                      "/ <abbr title='#{measurement_unit.description}'>#{measurement_unit_abbreviation}</abbr>"
                    else
                      "/ #{measurement_unit_abbreviation}"
                    end
        end
      else
        if duty_amount.present?
          output << if formatted
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
          output << '%'
        end
        if monetary_unit.present?
          output << monetary_unit
        end
        if measurement_unit_abbreviation.present?
          output << if formatted
                      "/ <abbr title='#{measurement_unit.description}'>#{measurement_unit_abbreviation}</abbr>"
                    else
                      "/ #{measurement_unit_abbreviation}"
                    end
        end
      end

      result = output.join(' ').html_safe

      if resolved_meursing_component
        "<strong>#{result}</strong>"
      else
        result
      end
    end

    private

    def html_formatted_duty_expression(duty_amount)
      "<span>#{prettify(duty_amount)}</span>"
    end
  end
end
