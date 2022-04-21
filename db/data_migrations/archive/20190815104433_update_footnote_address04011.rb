TradeTariffBackend::DataMigrator.migration do
  name 'Update footnote address 04011'

  FOOTNOTE_TYPE_ID = '04'
  FOOTNOTE_ID = '011'

  OLD_DESCRIPTION = "Contact Details for lead Government Department are as follows: <P> <P>Forestry  and Wood Products <P>Forestry Commission <P>231 Corstorphine Road <P>Edinburgh <P>EH12 7AT <P>Tel no : 0131 334 0303 <P>enquiries&#64;forestry.gsi.gov.uk"

  NEW_DESCRIPTION = "Contact Details for lead Government Department are as follows: <P> <P>Forestry and Wood Products <P>Forestry Commission <P><br>Silvan House,<P>231 Corstorphine Road,<P>Edinburgh,<P>EH12 7AT<P>Tel No. 0300 067 5034 (direct)<P>Email: plant.health&#64;forestrycommission.gov.uk"

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
