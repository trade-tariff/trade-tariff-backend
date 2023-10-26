node :pagination do
  {
    page: current_page,
    per_page:,
    total_count: @collection.pagination_record_count,
  }
end
