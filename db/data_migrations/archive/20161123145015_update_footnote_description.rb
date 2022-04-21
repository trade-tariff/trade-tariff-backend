TradeTariffBackend::DataMigrator.migration do
  name "Manual update of the description of the footnote 04004"

  FOOTNOTE_TYPE_ID = "04"
  FOOTNOTE_ID = "004"
  OLD_DESCRIPTION = "Contact Details for lead Government Department are as follows: <P> <P>Crops  Plants and Produce Division <P>Defra <P>Area 5a , Nobel House , <P>17 Smith Square <P>London.  <P>SW1P 3JR <P>Telephone: 020 7238 1044/1054 <P>Website: http://www.defra.gov.uk/hort/index.htm"
  NEW_DESCRIPTION = "Contact Details for lead Government Department are as follows: \n\n<P>Crops  Plants and Produce Division <P>DEFRA - Area 5A <P>Nobel House <P>17 Smith Square <P>London SW1P 3JR \n\n<P>Telephone: 020 7238 1044/1054 <P>Website: https://www.gov.uk/government/organisations/department-for-environment-food-rural-affairs"

  up do
    applicable {
      !FootnoteDescription.where(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID, description: OLD_DESCRIPTION).empty?
      false
    }

    apply {
      footnote_description = FootnoteDescription.find(footnote_type_id: FOOTNOTE_TYPE_ID, footnote_id: FOOTNOTE_ID)
      footnote_description.update(description: NEW_DESCRIPTION)
    }
  end

  down do
    applicable { false }
    apply { }
  end
end
