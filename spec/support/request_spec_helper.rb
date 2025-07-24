module RequestSpecHelper
  def authenticated_head(path, **kwargs)
    head path, **add_authentication_header(**kwargs)
  end

  def authenticated_get(path, **kwargs)
    get path, **add_authentication_header(**kwargs)
  end

  def authenticated_post(path, **kwargs)
    post path, **add_authentication_header(**kwargs)
  end

  def authenticated_patch(path, **kwargs)
    patch path, **add_authentication_header(**kwargs)
  end

  def authenticated_delete(path, **kwargs)
    delete path, **add_authentication_header(**kwargs)
  end

private

  def add_authentication_header(headers: {}, **kwargs)
    headers['HTTP_AUTHORIZATION'] ||= 'Bearer tariff-api-test-token'

    kwargs.merge(headers:)
  end
end
