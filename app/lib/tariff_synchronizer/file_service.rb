module TariffSynchronizer
  class FileService
    BYTE_SIZE = 16 * 1024 # 16KB
    class << self
      def get(file_path)
        if Rails.env.production?
          bucket.object(file_path).get.body
        else
          File.open(file_path)
        end
      end

      def write_file(file_path, body)
        if Rails.env.production?
          bucket.object(file_path).put(body:)
        else
          directory = File.dirname(file_path)

          FileUtils.mkdir_p(directory) unless File.exist?(directory)

          File.open(file_path, 'wb') { |f| f.write(body) }
        end
      end

      def file_exists?(file_path)
        if Rails.env.production?
          bucket.object(file_path).exists?
        else
          File.exist?(file_path)
        end
      end

      def file_size(file_path)
        if Rails.env.production?
          bucket.object(file_path).size
        else
          File.open(file_path).size
        end
      end

      def file_as_stringio(tariff_update)
        get(tariff_update.file_path)
      end

      def file_presigned_url(file_path)
        if Rails.env.production?
          bucket.object(file_path).presigned_url('get')
        else
          file_path
        end
      end

      def bucket
        Aws::S3::Resource.new.bucket(ENV['AWS_BUCKET_NAME'])
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
          s3_object = bucket.object(source)
          File.open(destination, 'wb') do |file|
            s3_object.get(response_target: file)
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
          bucket.objects(prefix:).map do |object|
            {
              path: object.key,
              last_modified: object.last_modified,
              size: object.size,
            }
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
    end
  end
end
