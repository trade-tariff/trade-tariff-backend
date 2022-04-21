TradeTariffBackend::DataMigrator.migration do
  name 'Update footnote 05_002 description'

  FOOTNOTE_TYPE_ID = '05'
  FOOTNOTE_ID = '002'
  OLD_DESCRIPTION = "BERR Export Licence \
    <P>For further information concerning export prohibitions and restrictions for this commodity, please contact: \
    <P>Department of Business Enterprise and Regulatory Reform \
    <P> <P>Export Control Organisation <P> \
    <P>3rd Floor, <P> \
    <P>1 Victoria Street <P> \
    <P>London SW1H 0ET <P> \
    <P>Tel: 020 7215 4594 <P> \
    <P>Email: eco.help&#64;berr.gsi.gov.uk <P> \
    <P><a href=\"http://www.bis.gov.uk/policies/export-control-organisation\">www.bis.gov.uk/policies/export-control-organisation</a>"
  NEW_DESCRIPTION = "<p>Export Control Organisation</p> \
    <p>For further information concerning export prohibitions and restrictions for this commodity, please contact:</p> \
    <p>Export Control Organisation</p> \
    <p>3rd Floor</p> \
    <p>1 Victoria Street</p> \
    <p>London</p> \
    <p>SW1H 0ET</p> \
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
