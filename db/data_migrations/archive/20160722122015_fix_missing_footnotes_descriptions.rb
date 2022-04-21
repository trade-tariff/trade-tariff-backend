TradeTariffBackend::DataMigrator.migration do
  name "Fix Missing Footnotes descriptions"

  up do
    applicable { false }
    # The apply block is idempotent
    apply {

      FootnoteDescription.unrestrict_primary_key
      FootnoteDescription.find_or_create(footnote_description_period_sid: "-109",
                                         footnote_type_id: "01",
                                         footnote_id: "425",
                                         language_id: "EN",
                                         description: "MADE-WINE OF BETWEEN 15%-22% VOL",
                                         national: true,
                                         operation: "U")
      FootnoteDescription.find_or_create(footnote_description_period_sid: "-162",
                                         footnote_type_id: "04",
                                         footnote_id: "001",
                                         language_id: "EN",
                                         description: "<p>Health and Safety Executive</p><p>Import Licensing</p><p>For further information concerning import prohibitions and restrictions for this commodity, please contact:</p><p>Health and Safety Executive</p><p>Mines, Quarries &amp; Explosives Policy</p><p>Rose Court</p><p>2 Southwark Bridge</p><p>London</p><p>SE1 9HS</p><p></p><p>Tel: 0207 717 6205</p><p>Fax: 0207 717 6690</p><p><a href='https://www.gov.uk/import-controls'>www.gov.uk/import-controls</a></p>",
                                         national: true,
                                         operation: "U")
    }
  end

  down do
    applicable { false }
    apply { } # noop
  end
end
