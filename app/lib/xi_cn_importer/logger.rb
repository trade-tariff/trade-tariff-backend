module XiCnImporter
  module Logger
    module_function

    def log(level, message, **context)
      formatted = context.map { |k, v| "#{k}=#{v}" }.join(' ')
      Rails.logger.public_send(level, "[XiCnImporter] #{message} #{formatted}".strip)
    end
  end
end
