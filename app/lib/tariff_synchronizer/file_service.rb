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
    end
  end
end
