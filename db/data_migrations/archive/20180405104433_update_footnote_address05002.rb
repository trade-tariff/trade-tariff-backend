TradeTariffBackend::DataMigrator.migration do
  name 'Update footnote address 05002'

  FOOTNOTE_TYPE_ID = '05'
  FOOTNOTE_ID = '002'

  OLD_DESCRIPTION = "<p>Export Control Organisation</p> \
    <p>For further information concerning export prohibitions and restrictions for this commodity, please contact:</p> \
    <p>Export Control Organisation</p> \
    <p>3rd Floor</p> \
    <p>1 Victoria Street</p> \
    <p>London</p> \
    <p>SW1H 0ET</p> \
    <p>Tel: 020 7215 4594</p> \
    <p>Email: eco.help&#64;trade.gsi.gov.uk</p> \
    <p><a href=\"https://www.gov.uk/government/policies/export-controls\">www.gov.uk/government/policies/export-controls</a></p>"

  NEW_DESCRIPTION = "<p>Export Control Organisation</p> \
    <p>For further information concerning export prohibitions and restrictions for this commodity, please contact:</p> \
    <p>Export Control Organisation</p> \
    <p>Department for International Trade</p> \
    <p>3 Whitehall Place</p> \
    <p>London</p> \
    <p>SW1A 2AW</p> \
    <p>Tel: 020 7215 4594</p> \
    <p>Email: eco.help&#64;trade.gsi.gov.uk</p> \
    <p><a href=\"https://www.gov.uk/government/policies/export-controls\">www.gov.uk/government/policies/export-controls</a></p>"

  up do
    applicable {
      f = Footnote.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).last
      f && f.footnote_description && f.footnote_description.description != NEW_DESCRIPTION
      false
    }

    apply {
      f = Footnote.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).last
      f.footnote_description.update(description: NEW_DESCRIPTION)
    }
  end

  down do
    applicable {
      f = Footnote.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).last
      f && f.footnote_description && f.footnote_description.description != OLD_DESCRIPTION
      false
    }

    apply {
      f = Footnote.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID).last
      f.footnote_description.update(description: OLD_DESCRIPTION)
    }
  end
end
