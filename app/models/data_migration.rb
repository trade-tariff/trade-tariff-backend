class DataMigration < Sequel::Model
  VERSION_FORMAT = /\A20\d{12}\z/

  dataset_module do
    def version(version)
      raise ArgumentError, 'Invalid version number' unless version =~ VERSION_FORMAT

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
end
