Sequel.migration do
  up do
    Sequel::Model.db[:sections]
      .where(
        numeral: 'IV',
        title: %(Prepared foodstuffs; beverages, spirits and vinegar; tobacco and manufactured tobacco substitutes),
      )
      .update(
        title: %(Prepared foodstuffs; beverages, spirits and vinegar; tobacco and manufactured tobacco substitutes; Products, whether or not containing nicotine, intended for inhalation without combustion; Other nicotine containing products intended for the intake of nicotine into the human body),
        updated_at: Time.zone.now.utc,
      )
  end

  down do
    Sequel::Model.db[:sections]
      .where(
        numeral: 'IV',
        title: %(Prepared foodstuffs; beverages, spirits and vinegar; tobacco and manufactured tobacco substitutes; Products, whether or not containing nicotine, intended for inhalation without combustion; Other nicotine containing products intended for the intake of nicotine into the human body),
      )
      .update(
        title: %(Prepared foodstuffs; beverages, spirits and vinegar; tobacco and manufactured tobacco substitutes),
        updated_at: nil,
      )
  end
end
