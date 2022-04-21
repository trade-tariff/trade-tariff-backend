TradeTariffBackend::DataMigrator.migration do
  name "Updates Footnote descriptions 04005 and 04018 with up to date data"

  TEXT_04005_NEW = 'Contact Details for lead Government Department are as follows: <P>Fruit and Vegetables conformity controls </P> <P>Horticultural Marketing Inspectorate ( HMI) </P><P>Rural Payments Agency </P><P> Office SCF3 South Core Produce Hall </P><P> Western International Market </P><P>Hayes Road </P><P>Southall</P><P>UB2 5XJ </P><P>Telephone 0845 6073224 </P><P>Email: Peachenquiries&#64;rpa.gsi.gov.uk'
  TEXT_04018_NEW = 'Contact Details for lead Government Department are as follows: <P>Fruit and Vegetables conformity controls </P> <P>Horticultural Marketing Inspectorate ( HMI) </P><P>Rural Payments Agency </P><P> Office SCF3 South Core Produce Hall </P><P> Western International Market </P><P>Hayes Road </P><P>Southall</P><P>UB2 5XJ </P><P>Telephone 0845 6073224 </P><P>Email: Peachenquiries&#64;rpa.gsi.gov.uk'
  TEXT_04005_OLD = 'Contact Details for lead Government Department are as follows: <P> <P>Fruit and Vegetables conformity controls <P> <P>Horticultural Marketing Inspectorate ( HMI) <P>Rural Payments Agency <P> Inspection Executive &#38; Development Unit <P> Epsom Road , <P>Guildford <P>Surrey <P>GU1 2LD. <P>Telephone: 01483 403340 <P>Email: HMI-TDC&#64;rpa.gsi.gov.uk'
  TEXT_04018_OLD = 'Contact Details for lead Government Department are as follows: <P> <P>Fruit and Vegetables conformity controls <P> <P>Horticultural Marketing Inspectorate ( HMI) <P>Rural Payments Agency <P> Inspection Executive &#38; Development Unit <P> Epsom Road , <P>Guildford <P>Surrey <P>GU1 2LD. <P>Telephone: 01483 403340 <P>Email: HMI-TDC&#64;rpa.gsi.gov.uk'

  up do
    applicable {
      FootnoteDescription::Operation.where(
        footnote_description_period_sid: -167
      ).where(
        Sequel.~(description: TEXT_04005_NEW)
      ).any? ||
      FootnoteDescription::Operation.where(
        footnote_description_period_sid: -183
      ).where(
        Sequel.~(description: TEXT_04018_NEW)
      ).any?
      false
    }

    apply {
      FootnoteDescription::Operation.where(
        footnote_description_period_sid: -167
      ).update(
        description: TEXT_04005_NEW
      )

      FootnoteDescription::Operation.where(
        footnote_description_period_sid: -183
      ).update(
        description: TEXT_04018_NEW
      )
    }
  end

  down do
    applicable {
      FootnoteDescription::Operation.where(
        footnote_description_period_sid: -167
      ).where(
        Sequel.~(description: TEXT_04005_OLD)
      ).any? ||
      FootnoteDescription::Operation.where(
        footnote_description_period_sid: -183
      ).where(
        Sequel.~(description: TEXT_04018_OLD)
      ).any?
      false
    }

    apply {
      FootnoteDescription::Operation.where(
        footnote_description_period_sid: -167
      ).update(
        description: TEXT_04005_OLD
      )

      FootnoteDescription::Operation.where(
        footnote_description_period_sid: -183
      ).update(
        description: TEXT_04018_OLD
      )
    }
  end
end
