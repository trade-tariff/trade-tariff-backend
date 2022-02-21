class QuotaOrderNumber < Sequel::Model
  plugin :time_machine
  plugin :oplog, primary_key: :quota_order_number_sid

  set_primary_key [:quota_order_number_sid]

  one_to_one :quota_definition, key: :quota_order_number_sid, primary_key: :quota_order_number_sid do |ds|
    ds.with_actual(QuotaDefinition)
  end

  dataset_module do
    def with_quota_definitions
      inner_join(:quota_definitions, quota_order_numbers__quota_order_number_sid: :quota_definitions__quota_order_number_sid)
        .actual
        .with_actual(QuotaDefinition)
        .eager(:quota_definition)
    end
  end

  LICENSED_QUOTA_PREFIXES = %w[094 084 074 064 054 044 034 024 014].freeze

  def quota_definition!
    return nil if quota_order_number_id.starts_with?(*LICENSED_QUOTA_PREFIXES)

    quota_definition
  end

  alias_method :definition, :quota_definition!

  def definition_id
    definition&.quota_definition_sid
  end

  alias_method :quota_definition_id, :definition_id

  one_to_one :quota_order_number_origin, primary_key: :quota_order_number_sid,
                                         key: :quota_order_number_sid do |ds|
    ds.with_actual(QuotaOrderNumberOrigin)
  end

  delegate :present?, to: :quota_order_number_origin, prefix: true, allow_nil: true
  delegate :geographical_area, to: :quota_order_number_origin, allow_nil: true

  def geographical_area_id
    geographical_area&.id
  end

  one_to_many :quota_order_number_origins,
              primary_key: :quota_order_number_sid,
              key: :quota_order_number_sid do |ds|
                ds.with_actual(QuotaOrderNumberOrigin)
              end

  def geographical_areas
    quota_order_number_origins.map(&:geographical_area)
  end

  def geographical_area_ids
    geographical_areas&.map(&:id)
  end
end
