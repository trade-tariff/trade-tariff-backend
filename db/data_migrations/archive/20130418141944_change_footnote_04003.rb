TradeTariffBackend::DataMigrator.migration do
  name "Updates Footnote description 04003"

  TEXT_04003_NEW = 'Contact Details for lead Government Department are as follows: <P> <P>Rabies &#38; Hares - Animal Health Certificate Animal - Rabies Pathogens, Hares <P> <P>Animal Health & Veterinary Laboratories Agency</P><P>Hadrian House</P><P>Wavell Drive</P><P>Rosehill</P><P>Carlisle</P><P>CA1 2TB</P><P>Telephone: 01228 403600</P><P>Fax: 01228 591900</P><P> <P>Animal Pathogens Import Licence <P> <P>The Pathogens Licensing Team <P>Defra <P>Area 5A, Nobel House <P>17 Smith Square,London <P>SW1P 3JR <P>Telephone: 020 7238 6211/6195 <P>Fax: 020 7238 6105 <P>Email:pathogens&#64;defra.gsi.gov.uk <P>Website: <a href="http://www.defra.gov.uk/animal-diseases/pathogens/">www.defra.gov.uk/animal-diseases/pathogens/</a>'
  TEXT_04003_OLD = 'Contact Details for lead Government Department are as follows: <P> <P>Rabies &#38; Hares - Animal Health Certificate Animal - Rabies Pathogens, Hares <P> <P>Government Offices <P>Beeches Road <P>Chelmsford <P>Essex <P>CM1 2RU <P>Telephone: 01245 358383/490886 <P> <P>Animal Pathogens Import Licence <P> <P>The Pathogens Licensing Team <P>Defra <P>Area 5A, Nobel House <P>17 Smith Square,London <P>SW1P 3JR <P>Telephone: 020 7238 6211/6195 <P>Fax: 020 7238 6105 <P>Email:pathogens&#64;defra.gsi.gov.uk <P>Website: <a href=\"http://www.defra.gov.uk/animal-diseases/pathogens/\">www.defra.gov.uk/animal-diseases/pathogens/</a>'

  up do
    applicable {
      FootnoteDescription::Operation.where(
        footnote_description_period_sid: -164
      ).where(
        Sequel.~(description: TEXT_04003_NEW)
      ).any?
      false
    }

    apply {
      FootnoteDescription::Operation.where(
        footnote_description_period_sid: -164
      ).update(
        description: TEXT_04003_NEW
      )
    }
  end

  down do
    applicable {
      FootnoteDescription::Operation.where(
        footnote_description_period_sid: -164
      ).where(
        Sequel.~(description: TEXT_04003_OLD)
      ).any?
      false
    }

    apply {
      FootnoteDescription::Operation.where(
        footnote_description_period_sid: -164
      ).update(
        description: TEXT_04003_OLD
      )
    }
  end
end
