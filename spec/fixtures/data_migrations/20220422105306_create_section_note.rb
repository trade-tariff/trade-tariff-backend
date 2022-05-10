Sequel.migration do
  test_attrs = { section_id: '9999', content: 'Data migration test' }

  up do
    if SectionNote.where(test_attrs).count.zero?
      SectionNote.create(test_attrs)
    end
  end

  down do
    SectionNote.where(test_attrs).delete
  end
end
