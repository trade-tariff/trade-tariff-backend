class LiveIssue < Sequel::Model(Sequel[:live_issues].qualify(:public))
  plugin :timestamps, update_on_create: true
  plugin :auto_validations, not_null: :presence

  def validate
    super

    validates_includes %w[Active Resolved], :status
  end
end
