class CustomsTariffChapterNote < Sequel::Model
  many_to_one :customs_tariff_update, key: :customs_tariff_update_version
end
