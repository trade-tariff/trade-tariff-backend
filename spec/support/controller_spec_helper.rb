module ControllerSpecHelper
  def pagination_pattern
    { pagination:
      {
        page: 1,
        per_page: Integer,
        total_count: Integer,
      } }.ignore_extra_keys!
  end
end
