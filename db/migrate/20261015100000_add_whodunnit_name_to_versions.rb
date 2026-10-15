Sequel.migration do
  change do
    alter_table(:versions) do
      # The admin user's name when the change was made (HMRC-2764). Admin sends it in the
      # X-Whodunnit-Name header. Nullable: system changes and older versions have no name.
      add_column :whodunnit_name, String
    end
  end
end
