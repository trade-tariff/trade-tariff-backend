class GovukNotifierAudit < Sequel::Model(Sequel[:govuk_notifier_audits].qualify(:public))
  plugin :timestamps, update_on_create: true
  plugin :auto_validations, not_null: :presence
end
