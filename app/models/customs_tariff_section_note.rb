class CustomsTariffSectionNote < Sequel::Model
  plugin :has_paper_trail
  plugin :time_machine

  many_to_one :customs_tariff_update, key: :customs_tariff_update_version
end
