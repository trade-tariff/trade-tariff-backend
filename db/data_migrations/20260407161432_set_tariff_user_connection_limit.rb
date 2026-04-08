Sequel.migration do
  up do
    run "ALTER ROLE tariff CONNECTION LIMIT 450;"
  end

  down do
    run "ALTER ROLE tariff CONNECTION LIMIT -1;"
  end
end

