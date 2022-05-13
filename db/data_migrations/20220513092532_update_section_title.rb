Sequel.migration do
  up do
    Sequel::Model.db[:sections]
      .where(
        numeral: 'III',
        title: %(Animal or vegetable fats and oils and their cleavage products; prepared edible fats; animal or vegetable waxes),
      )
      .update(
        title: %(Animal, vegetable or microbial fats and oils and their cleavage products; prepared edible fats; animal or vegetable waxes),
        updated_at: Time.zone.now.utc,
      )
  end

  down do
    Sequel::Model.db[:sections]
      .where(
        numeral: 'III',
        title: %(Animal, vegetable or microbial fats and oils and their cleavage products; prepared edible fats; animal or vegetable waxes),
      )
      .update(
        title: %(Animal or vegetable fats and oils and their cleavage products; prepared edible fats; animal or vegetable waxes),
        updated_at: nil,
      )
  end
end
