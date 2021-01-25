module TariffSynchronizer
  class FileService
    class << self
      # Uploads local file to S3 bucket
      def upload_file(src_path, dst_path)
        if Rails.env.production? && File.exist?(src_path)
          bucket.object(dst_path).upload_file(src_path)
        end
      end

      # Deletes file by path
      def delete_file(file_path)
        if Rails.env.production? && file_exists?(file_path)
          bucket.object(file_path).delete
        end
      end

      def write_file(file_path, body)
        if Rails.env.production?
          bucket.object(file_path).put(body: body)
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
        if Rails.env.production?
          bucket.object(tariff_update.file_path).get.body
        else
          File.open(tariff_update.file_path)
        end
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
