Sequel.migration do
  up do
    Sequel::Model.db[:data_migrations]
      .where { filename.like('%/data_migrations/20%') }
      .update("filename = SPLIT_PART(filename, '/data_migrations/', 2)")
  end

  down do
    raise 'Not reversible'
  end
end
