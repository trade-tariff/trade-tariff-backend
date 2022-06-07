# frozen_string_literal: true

Sequel.migration do
  up do
    SearchReference.where(referenced_class: 'Section').delete
  end

  down do
  end
end
