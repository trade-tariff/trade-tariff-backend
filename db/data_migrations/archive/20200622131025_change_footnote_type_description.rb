TradeTariffBackend::DataMigrator.migration do
  name "Change footnote type description if contains _oplog"

  up do
    applicable { false }
    apply {
      change_footnote_type_description
    }
  end

  down do
    applicable { false }
    apply { }
  end

  def change_footnote_type_description
    FootnoteTypeDescription::Operation.where("description ILIKE '%_oplog%'").paged_each do |ftd|
      ftd.update(description: ftd.description.gsub("_oplog", ""))
    end
  end
end
