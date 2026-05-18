Sequel.migration do
  up do
    run "ALTER ROLE tariff CONNECTION LIMIT 790;"
  end

  down do
     # Intentionally left blank — connection limit should not be removed
  end
end
