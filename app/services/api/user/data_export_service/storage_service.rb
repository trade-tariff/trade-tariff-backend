module Api
  module User
    module DataExportService
      class StorageService
        LOCAL_STORAGE_ROOT = Rails.root.join('tmp', 'data_exports').freeze

        def initialize(bucket_name: ENV['AWS_BUCKET_NAME'], region: ENV.fetch('AWS_DEFAULT_REGION', nil))
          return unless production?

          @resource = Aws::S3::Resource.new(region: region)
          @bucket = @resource.bucket(bucket_name)
        end

        def upload(key:, body:, content_type:)
          if production?
            @bucket.object(key).put(body: body, content_type: content_type)
            return
          end

          path = local_path(key)
          FileUtils.mkdir_p(path.dirname)
          File.binwrite(path, body)
        end

        def presigned_get_url(key:, expires_in: 300)
          return @bucket.object(key).presigned_url(:get, expires_in: expires_in) if production?

          "file://#{local_path(key)}"
        end

        def download(key:)
          return @bucket.object(key).get.body.read if production?

          File.binread(local_path(key))
        end

      private

        def production?
          Rails.env.production?
        end

        def local_path(key)
          path = LOCAL_STORAGE_ROOT.join(key)
          path = path.cleanpath

          return path if path.to_s.start_with?(LOCAL_STORAGE_ROOT.to_s)

          raise ArgumentError, 'Invalid storage key path'
        end
      end
    end
  end
end
