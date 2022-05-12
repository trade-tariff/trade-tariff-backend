Sequel.migration do
  up do
    return unless TradeTariffBackend.uk?

    Sequel::Model.db[:footnote_descriptions_oplog]
      .where {
        (footnote_id =~ '808') &
          (footnote_type_id =~ 'CD') &
          (footnote_description_period_sid =~ 200_705) &
          description.like("%'>aRegulation (EC)%") &
          (operation_date =~ '2022-04-25')
      }
      .update(description: %(Where goods are not accompanied by a Certificate of Inspection attesting that they conform to the requirements of <a href='https://www.legislation.gov.uk/eur/2007/834/introduction'>Regulation (EC) No 834/2007</a> and <a href='https://www.legislation.gov.uk/eur/2008/889/contents'>Regulation (EC) No 889/2008</a> as retained in UK law, they will not be released for free circulation unless references to organic production are removed from the labelling, advertising and accompanying documents.))
  end

  down {}
end
