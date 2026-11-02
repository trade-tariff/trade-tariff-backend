Sequel.migration do
  test_attrs = { section_id: '9999', content: 'Data migration test' }

  up do
    if self[:section_notes].where(test_attrs).count.zero?
      self[:section_notes].insert(test_attrs)
    end
  end

  down do
    self[:section_notes].where(test_attrs).delete
  end
end
