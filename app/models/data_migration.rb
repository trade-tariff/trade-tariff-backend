class DataMigration < Sequel::Model
  VERSION_FORMAT = /\A20\d{12}\z/

  set_dataset order(Sequel.asc(:filename))

  dataset_module do
    def version(version)
      raise ArgumentError, 'Invalid version number' unless VERSION_FORMAT.match?(version)

      where Sequel.like(:filename, "#{version}_%.rb")
    end

    def since(timestamp)
      version = timestamp.strftime('%Y%m%d%H%M%S')

      where(Sequel.lit("SPLIT_PART(filename, '_', 1) > ?", version))
        .order(Sequel.asc(:filename))
    end

    def upto(timestamp)
      version = timestamp.strftime('%Y%m%d%H%M%S')

      where(Sequel.lit("SPLIT_PART(filename, '_', 1) < ?", version))
        .order(Sequel.asc(:filename))
    end

    def within(since, upto)
      since(since).upto(upto)
    end
  end

  def version
    filename.first(14)
  end
end
