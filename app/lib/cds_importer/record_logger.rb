class CdsImporter
  class RecordLogger
    def initialize(filename)
      @filename = filename
      @all_sqls = []
    end

    def process_record(cds_entity)
      unless cds_entity.instance.skip_import?
        operation_klass = cds_entity.instance.class.operation_klass
        values = cds_entity.instance.values.slice(*operation_klass.columns).except(:oid)
        values[:filename] = filename

        if operation_klass.columns.include?(:created_at)
          values[:created_at] = operation_klass.dataset.current_datetime
        end

        @all_sqls << operation_klass.dataset.insert_sql(values)
      end
    end

    def after_parse
      write_to_file
    end

    private

    def write_to_file
      sql_body = @all_sqls.map { |sql| "#{sql};" }.join("\n") + "\n"
      sql_filename = "cds_#{xml_to_file_date}.sql"
      file_path = File.join(TariffSynchronizer.root_path, 'XI_CDS_Test', sql_filename)

      TariffSynchronizer::FileService.write_file(file_path, sql_body)
    end

    def xml_to_file_date
      if filename =~ /(\d{8})T/
        raw_date = Regexp.last_match(1)
        year  = raw_date[0, 4]
        month = raw_date[4, 2]
        day   = raw_date[6, 2]

        "#{year}-#{month}-#{day}"
      else
        ''
      end
    end

    attr_reader :filename

  end
end
