Sequel.migration do
  test_attrs = { title: 'Data migration test', url: 'https://example.com/guide' }

  up do
    if Guide.where(test_attrs).count.zero?
      Guide.create(test_attrs)
    end
  end

  down do
    Guide.where(test_attrs).delete
  end
end
