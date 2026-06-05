module TariffKnowledge
  RuleSource = Data.define(
    :key,
    :source_type,
    :source_id,
    :source_version,
    :title,
    :content,
    :scope_type,
    :scope_id,
    :validity_start_date,
    :validity_end_date,
  )
end
