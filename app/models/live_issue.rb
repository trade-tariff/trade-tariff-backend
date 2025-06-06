class LiveIssue < Sequel::Model(Sequel[:live_issues].qualify(:public))
  plugin :timestamps, update_on_create: true
  plugin :auto_validations, not_null: :presence

  def validate
    super

    validates_presence [:title, :status, :commodities, :date_discovered]
    validates_max_length 256, :description
    validates_includes ['Active', 'Resolved'], :status
  end
end
