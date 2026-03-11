Sequel.migration do
  # Mapping from admin app's User.id to User.uid (from production admin DB)
  USER_ID_TO_UID = {
    1 => 'f6627224-c051-70ee-cc83-9780fa86e30e',
    2 => '26027204-e001-7013-1bec-e442d527c43d',
    4 => '4480c060-91f8-013c-2000-1e807ed4456b',
    5 => 'f6a2a2a4-f0f1-7087-72dc-8fd0b21ba994',
    8 => '60eade00-b442-0136-d027-005056010932',
    9 => '5652a2a4-50b1-70dc-bb30-18f86abf2b38',
    11 => '86e2f254-10d1-707d-5f36-c68938f20bad',
    12 => '8662b244-00e1-706d-dd09-755b44bf6e5b',
    13 => '766292f4-40f1-7054-10bf-0c07c95f55a2',
    15 => '26c25214-60c1-708f-310d-72c7f1504071',
    16 => '3672c264-7011-7046-39e5-d14619a57696',
    17 => '6692c274-f051-7041-a8ba-532e3a93702a',
    18 => '264242d4-0021-7091-0724-a5a35a94fc0c',
    19 => 'b6f2d264-3071-7013-bb8e-925cd7ba74e0',
  }.freeze

  up do
    %i[applies downloads rollbacks cds_update_notifications].each do |table|
      alter_table(table) do
        add_column :whodunnit, String, text: true
      end
    end

    USER_ID_TO_UID.each do |user_id, uid|
      %i[applies downloads rollbacks cds_update_notifications].each do |table|
        from(table).where(user_id: user_id).update(whodunnit: uid)
      end
    end

    %i[applies downloads cds_update_notifications].each do |table|
      alter_table(table) do
        drop_column :user_id
      end
    end

    alter_table(:rollbacks) do
      drop_index :user_id, name: :user_id
      drop_column :user_id
    end
  end

  down do
    %i[applies downloads rollbacks cds_update_notifications].each do |table|
      alter_table(table) do
        add_column :user_id, Integer
      end
    end

    USER_ID_TO_UID.each do |user_id, uid|
      %i[applies downloads rollbacks cds_update_notifications].each do |table|
        from(table).where(whodunnit: uid).update(user_id: user_id)
      end
    end

    %i[applies downloads cds_update_notifications].each do |table|
      alter_table(table) do
        drop_column :whodunnit
      end
    end

    alter_table(:rollbacks) do
      add_index :user_id, name: :user_id
      drop_column :whodunnit
    end
  end
end
