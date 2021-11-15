module TradeTariffBackend
  class NumberFormatter
    # NOTE: Port to ActiveSupport::NumberHelper when on Rails 4
    include ActionView::Helpers::NumberHelper

    # Extension to #number_with_precision that allows
    # to have certain number of decimal zeros even
    # when stripping of insignificant zeros is enabled
    #
    # E.g.:
    #
    # number_with_precision(1.2, minimum_decimal_points: 2) => '1.20'
    # number_with_precision(1.2456, minimum_decimal_points: 2, precision: 4, strip_insignificant_zeros: true) => '1.2456'
    # number_with_precision(1.3, minimum_decimal_points: 2, precision: 4, strip_insignificant_zeros: true) => '1.30'

    def number_with_precision(number, opts = {})
      minimum_decimal_points = opts.delete(:minimum_decimal_points)
      formatted_number = super(number, opts)

      if minimum_decimal_points && precision_for(formatted_number) < minimum_decimal_points
        "%.#{minimum_decimal_points}f" % formatted_number.to_f
      else
        formatted_number
      end
    end

  private

    def precision_for(number)
      number.to_f.to_s.split('.').last.size
    end
  end
end
