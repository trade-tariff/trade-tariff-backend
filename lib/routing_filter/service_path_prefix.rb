module RoutingFilter
  class ServicePathPrefix < Filter
    SERVICE_CHOICE_PREFIXES = /^\/(uk|xi)(?=\/|$)/

    def around_recognize(path, _env)
      extract_segment!(SERVICE_CHOICE_PREFIXES, path)

      yield
    end
  end
end
