######### Conformance validations 250
class GeographicalAreaValidator < TradeTariffBackend::Validator
  validation :GA1, 'The combination geographical area id + validity start date must be unique.', on: %i[create update] do
    validates :uniqueness, of: %i[geographical_area_id validity_start_date]
  end

  validation :GA2, 'The start date must be less than or equal to the end date.' do
    validates :validity_dates
  end

  validation :GA4, 'The referenced parent geographical area group must be an existing geographical area with area code = 1 (geographical area group)', on: %i[create update] do |record|
    parent_sid = record.parent_geographical_area_group_sid
    if parent_sid.present?
      parent = record.class[geographical_area_sid: parent_sid]
      parent.try(:geographical_code).to_s == '1'
    end
  end

  validation :GA5, 'If a geographical area has a parent geographical area group then the validity period of the parent geographical area group must span the validity period of the geographical area', on: %i[create update] do |record|
    if record.parent_geographical_area.present?
      parent = record.parent_geographical_area
      conditions = []
      conditions << -> { parent.validity_start_date.to_i <= record.validity_start_date.to_i }
      if parent.validity_end_date
        conditions << -> { record.validity_end_date.present? }
        conditions << -> { parent.validity_end_date.to_i >= record.validity_end_date.to_i }
      end
      conditions.inject(true) do |valid, condition|
        break valid unless valid

        valid && condition.call
      end
    end
  end

  validation :GA6, 'Loops in the parent relation between geographical areas and parent geographical area groups are not allowed. If a geographical area A is a parent geographical area group of B then B cannot be a parent geographical area group of A (loops can also exist on more than two levels, e.g. level 3; If A is a parent of B and B is a parent of C then C cannot be a parent of A).', on: %i[create update] do |record|
    children_chain = []
    children_chain << record.geographical_area_sid if record.geographical_area_sid
    if parent = record.parent_geographical_area
      while parent && !@has_error
        if sid = parent.geographical_area_sid
          @has_error ||= children_chain.include?(sid)
          children_chain << sid
        end
        parent = parent.parent_geographical_area
      end
    end
    !@has_error
  end
end

# TODO: GA3
# TODO: GA7
# TODO: GA10
# TODO: GA11
# TODO: GA12
# TODO: GA13
# TODO: GA14
# TODO: GA15
# TODO: GA16
# TODO: GA17
# TODO: GA18
# TODO: GA19
# TODO: GA20
# TODO: GA21
# TODO: GA22
# TODO: GA23
