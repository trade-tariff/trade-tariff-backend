class DataExportWorker
  include Sidekiq::Worker
  sidekiq_options queue: :default, retry: false

  DATA_EXPORT_OBJECT_KEY = 'data/export/'.freeze

  def perform(data_export_id)
    data_export = PublicUsers::DataExport[data_export_id]
    return unless data_export

    data_export.update(status: PublicUsers::DataExport::PROCESSING)

    klass = data_export.exporter_klass
    result = klass.export_payload(data_export.exporter_args)
    date = Time.zone.today

    key = "#{DATA_EXPORT_OBJECT_KEY}#{date.strftime('%Y')}/#{date.strftime('%m')}/#{date.strftime('%d')}/#{data_export.export_type}/#{data_export.id}_#{result[:file_name]}"

    storage = Api::User::DataExportService::StorageService.new
    storage.upload(
      key: key,
      body: result[:body],
      content_type: result[:content_type],
    )

    data_export.update(
      status: PublicUsers::DataExport::COMPLETED,
      s3_key: key,
      file_name: result[:file_name],
    )
  rescue StandardError => e
    data_export&.update(status: PublicUsers::DataExport::FAILED)
    Sidekiq.logger.error(
      "[DataExporterWorker] failed data_export_id=#{data_export_id} error_class=#{e.class} error_message=#{e.message}",
    )
    raise
  end
end
