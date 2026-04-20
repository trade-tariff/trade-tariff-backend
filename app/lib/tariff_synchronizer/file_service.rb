module TariffSynchronizer
  class FileService
    BYTE_SIZE = 16 * 1024 # 16KB
    S3_MAX_RETRIES = 3

    # Errors that indicate the S3 object or access is permanently broken.
    # These fail immediately — retrying will not help.
    NON_TRANSIENT_S3_ERRORS = [
      Aws::S3::Errors::NoSuchKey,
      Aws::S3::Errors::AccessDenied,
      Aws::S3::Errors::NoSuchBucket,
    ].freeze

    class << self
      def get(file_path)
        if Rails.env.production?
          with_s3_retry(operation: 'get', file_path:) do
            bucket.object(file_path).get.body
          end
        else
          File.open(file_path)
        end
      end

      def write_file(file_path, body)
        if Rails.env.production?
          with_s3_retry(operation: 'write_file', file_path:) do
            bucket.object(file_path).put(body:)
          end
        else
          directory = File.dirname(file_path)

          FileUtils.mkdir_p(directory) unless File.exist?(directory)

          File.open(file_path, 'wb') { |f| f.write(body) }
        end
      end

      def file_exists?(file_path)
        if Rails.env.production?
          with_s3_retry(operation: 'file_exists?', file_path:) do
            bucket.object(file_path).exists?
          end
        else
          File.exist?(file_path)
        end
      end

      def file_size(file_path)
        if Rails.env.production?
          with_s3_retry(operation: 'file_size', file_path:) do
            bucket.object(file_path).size
          end
        else
          File.open(file_path).size
        end
      end

      def file_as_stringio(tariff_update)
        get(tariff_update.file_path)
      end

      def file_presigned_url(file_path)
        if Rails.env.production?
          with_s3_retry(operation: 'file_presigned_url', file_path:) do
            bucket.object(file_path).presigned_url('get')
          end
        else
          file_path
        end
      end

      def bucket
        Aws::S3::Resource.new.bucket(ENV['AWS_BUCKET_NAME'])
      end

      # Note currently the worker only has access to delete in the *persistence-bucket*/data/exchange_rates/*
      def delete_file(file_path, verify)
        return unless verify

        if Rails.env.production? && file_exists?(file_path)
          s3_client = Aws::S3::Client.new
          with_s3_retry(operation: 'delete_file', file_path:) do
            s3_client.delete_object(bucket: bucket.name, key: bucket.object(file_path).key)
          end
        else
          File.delete(file_path)
        end
      end

      def download_and_gunzip(source:, destination:)
        directory = File.dirname(destination)

        FileUtils.rm_rf(directory) if File.exist?(directory)
        FileUtils.mkdir_p(directory)

        download(source:, destination:)
        gunzip(source: destination, destination: destination.to_s.gsub('.gz', ''))

        Dir.glob("#{directory}/*").reject { |file| file.end_with?('.gz') }
      end

      def download(source:, destination:)
        if Rails.env.production?
          with_s3_retry(operation: 'download', file_path: source) do
            s3_object = bucket.object(source)
            File.open(destination, 'wb') do |file|
              s3_object.get(response_target: file)
            end
          end
        else
          FileUtils.cp(source, destination)
        end
      end

      def gunzip(source:, destination:)
        File.open(destination, 'wb') do |output|
          Zlib::GzipReader.open(source) do |input|
            bytes = input.read(BYTE_SIZE)

            while bytes
              output.write(bytes)
              bytes = input.read(BYTE_SIZE)
            end
          end
        end
      end

      def list_by(prefix:)
        if Rails.env.production?
          with_s3_retry(operation: 'list_by', file_path: prefix) do
            bucket.objects(prefix:).map do |object|
              {
                path: object.key,
                last_modified: object.last_modified,
                size: object.size,
              }
            end
          end
        else
          Dir.glob("#{prefix}*").map do |file_path|
            {
              path: file_path,
              last_modified: File.mtime(file_path),
              size: File.size(file_path),
            }
          end
        end
      end

      private

      def with_s3_retry(operation:, file_path:)
        attempts = 0
        begin
          attempts += 1
          yield
        rescue Seahorse::Client::NetworkingError, Aws::Errors::ServiceError => e
          if !transient_s3_error?(e)
            Rails.logger.error("FileService #{operation} failed (non-transient) for '#{file_path}': #{e.class}: #{e.message}")
            raise
          elsif attempts <= S3_MAX_RETRIES
            Rails.logger.warn("FileService #{operation} attempt #{attempts} failed for '#{file_path}': #{e.message}. Retrying...")
            s3_backoff(attempts)
            retry
          else
            Rails.logger.error("FileService #{operation} failed for '#{file_path}' after #{S3_MAX_RETRIES} retries: #{e.message}")
            raise
          end
        end
      end

      def transient_s3_error?(error)
        return true if error.is_a?(Seahorse::Client::NetworkingError)
        return false if NON_TRANSIENT_S3_ERRORS.any? { |klass| error.is_a?(klass) }

        error.is_a?(Aws::Errors::ServiceError)
      end

      def s3_backoff(attempt)
        sleep(2**attempt)
      end
    end
  end
end
