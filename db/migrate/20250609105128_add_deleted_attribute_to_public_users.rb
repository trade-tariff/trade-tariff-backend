Sequel.migration do
  change do
    unless self[:public__users].columns.include?(:deleted)
      alter_table(:public__users) do
        add_column :deleted, TrueClass, default: false
      end
    end
  end
end
