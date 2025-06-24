class GeographicalArea < Sequel::Model
  COUNTRIES_CODES = %w[0 2].freeze
  GROUPS_CODE = '1'.freeze
  AREAS_CODES = %w[0 1 2].freeze
  ERGA_OMNES_ID = '1011'.freeze
  AREAS_SUBJECT_TO_VAT_OR_EXCISE_ID = '1400'.freeze
  REFERENCED_GEOGRAPHICAL_AREAS = { 'EU' => '1013' }.freeze
  GSP = %w[2005 2020 2027].freeze
  DCTS = %w[1060 1061 1062].freeze

  plugin :time_machine
  plugin :oplog, primary_key: :geographical_area_sid, materialized: true

  set_primary_key :geographical_area_sid

  many_to_many :geographical_area_descriptions,
               join_table: :geographical_area_description_periods,
               left_primary_key: :geographical_area_sid,
               left_key: :geographical_area_sid,
               right_key: %i[geographical_area_description_period_sid
                             geographical_area_sid],
               right_primary_key: %i[geographical_area_description_period_sid
                                     geographical_area_sid] do |ds|
    ds.with_actual(GeographicalAreaDescriptionPeriod)
      .order(Sequel.desc(:geographical_area_description_periods__validity_start_date))
  end

  many_to_one :referenced, class: 'GeographicalArea',
                           primary_key: :geographical_area_id,
                           key: :referenced_id do |ds|
    ds.with_actual(GeographicalArea)
  end

  def geographical_area_description
    geographical_area_descriptions.first
  end

  many_to_one :parent_geographical_area, class: self
  one_to_many :children_geographical_areas, key: :parent_geographical_area_group_sid,
                                            class: self

  one_to_one :parent_geographical_area, key: :geographical_area_sid,
                                        primary_key: :parent_geographical_area_group_sid,
                                        class_name: 'GeographicalArea'

  many_to_many :contained_geographical_areas, class_name: 'GeographicalArea',
                                              join_table: :geographical_area_memberships,
                                              left_key: :geographical_area_group_sid,
                                              right_key: :geographical_area_sid,
                                              class: self do |ds|
    ds.with_actual(GeographicalAreaMembership).order(Sequel.asc(:geographical_area_id))
  end

  many_to_many :included_geographical_areas, class_name: 'GeographicalArea',
                                             join_table: :geographical_area_memberships,
                                             left_key: :geographical_area_sid,
                                             right_key: :geographical_area_group_sid,
                                             class: self do |ds|
    ds.with_actual(GeographicalAreaMembership).order(Sequel.asc(:geographical_area_id))
  end

  def candidate_excluded_geographical_area_ids
    @candidate_excluded_geographical_area_ids ||= contained_geographical_area_ids << geographical_area_id
  end

  def contained_geographical_area_ids
    contained_geographical_areas.pluck(:geographical_area_id)
  end

  one_to_many :measures, key: :geographical_area_sid,
                         primary_key: :geographical_area_sid do |ds|
    ds.with_actual(Measure)
  end


  dataset_module do
    def by_id(id)
      where(geographical_area_id: id)
    end

    def latest
      order(Sequel.desc(:operation_date))
    end

    def countries
      where(geographical_code: COUNTRIES_CODES).order(:geographical_area_id)
    end

    def groups
      where(geographical_code: GROUPS_CODE).order(:geographical_area_id)
    end

    def areas
      where(geographical_code: AREAS_CODES).order(:geographical_area_id)
    end
  end

  delegate :description, to: :geographical_area_description

  def id
    geographical_area_id
  end

  def gsp_or_dcts?
    GSP.include?(geographical_area_id) || DCTS.include?(geographical_area_id)
  end

  def referenced_or_self
    referenced.presence || self
  end

  private

  def referenced_id
    REFERENCED_GEOGRAPHICAL_AREAS[geographical_area_id]
  end

  def erga_omnes?
    id == ERGA_OMNES_ID
  end
end
