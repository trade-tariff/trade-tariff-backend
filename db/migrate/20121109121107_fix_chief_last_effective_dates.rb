Sequel.migration do
  no_transaction

  # Makes sure that there is only one TAME record per (msrgp_code, msr_type, tty_code, tar_msr_no) group that has blank validity end date.
  # Fixes CHIEF initial load.
  up do
    tame_primary_key = %i[
      msrgp_code
      msr_type
      tty_code
      tar_msr_no
      fe_tsmp
      le_tsmp
      audit_tsmp
      amend_indicator
    ]

    chief_tame = from(:chief_tame)

    chief_tame
      .select(:msrgp_code, :msr_type, :tty_code)
      .where(tar_msr_no: nil)
      .distinct
      .order(:msrgp_code, :msr_type, :tty_code)
      .each do |ref_tame|
        tames = chief_tame
          .where(
            msrgp_code: ref_tame[:msrgp_code],
            msr_type: ref_tame[:msr_type],
            tty_code: ref_tame[:tty_code],
          )
          .order(:fe_tsmp)
          .all

        blank_tames = tames.select { |tame| tame[:le_tsmp].nil? }
        next unless blank_tames.size > 1

        blank_tames.each do |blank_tame|
          next if blank_tame == tames.last

          next_tame = tames[tames.index(blank_tame) + 1]

          chief_tame
            .where(tame_primary_key.index_with { |key| blank_tame[key] })
            .update(le_tsmp: next_tame[:fe_tsmp])
        end
      end
  end

  down do
  end
end
