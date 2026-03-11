class Version < Sequel::Model
  dataset_module do
    def by_item_type(type)
      where(item_type: type)
    end

    def by_item_id(id)
      where(item_id: id)
    end

    def by_event(event)
      where(event: event)
    end

    def most_recent_first
      order(Sequel.desc(:created_at))
    end
  end

  def reify
    klass = item_type.constantize
    instance = klass.new
    object.each do |key, value|
      instance.values[key.to_sym] = value
    end
    instance
  end

  def previous_version
    return @previous_version if defined?(@previous_version)

    current_id = id

    @previous_version = Version
      .where(item_type: item_type, item_id: item_id)
      .where(Sequel[:id] < current_id)
      .order(Sequel.desc(:id))
      .first
  end

  attr_writer :previous_version

  def previous_version_id
    previous_version&.id
  end

  def changeset
    return nil if event == 'create'

    prev = previous_version
    return nil if prev.nil?

    VersionDiffService.new(item_type, prev.object, object).call
  end

  def self.preload_predecessors(versions)
    return versions if versions.empty?

    max_id = versions.map(&:id).max
    item_keys = versions.map { |v| [v.item_type, v.item_id] }.uniq

    # Build OR conditions for each (item_type, item_id) pair
    conditions = item_keys.map { |type, id| Sequel.&(Sequel[:item_type] =~ type, Sequel[:item_id] =~ id) }
    combined = conditions.length == 1 ? conditions.first : Sequel.|(*conditions)

    # Fetch all candidate predecessors: same (item_type, item_id), id < max of the batch.
    # We use max_id (not min_id) because event filtering may exclude predecessors
    # whose ids fall between min_id and a version's own id.
    candidates = Version
      .where(combined)
      .where(Sequel[:id] < max_id)
      .order(Sequel.desc(:id))
      .all

    # Group candidates by (item_type, item_id), already ordered by id desc
    grouped = candidates.group_by { |v| [v.item_type, v.item_id] }

    # Also include the versions themselves as potential predecessors for each other
    versions_by_key = versions.group_by { |v| [v.item_type, v.item_id] }

    versions.each do |v|
      siblings = (versions_by_key[[v.item_type, v.item_id]] || []) +
        (grouped[[v.item_type, v.item_id]] || [])

      v.previous_version = siblings
        .select { |c| c.id < v.id }
        .max_by(&:id)
    end

    versions
  end
end
