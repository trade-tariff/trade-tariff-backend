module TariffSynchronizer
  class FileService
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

      def download_and_unzip(source:, destination:)
        Dir.glob("#{File.dirname(destination)}/*").each do |file|
          FileUtils.rm(file)
        end

        download(source:, destination:)
        unzip(source: destination, destination: File.dirname(destination))

        Dir.glob("#{File.dirname(destination)}/*").reject { |file| file.end_with?('.zip') }
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

      def unzip(source:, destination:)
        Zip::File.open(source) do |zip_file|
          zip_file.each do |entry|
            entry.extract(File.join(destination, entry.name))
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
