# frozen_string_literal: true

Sequel.migration do
  up do
    run 'ALTER TABLE sections ALTER COLUMN title TYPE varchar(500)'
  end

  down do
    run 'ALTER TABLE sections ALTER COLUMN title TYPE varchar(255)'
  end
end
