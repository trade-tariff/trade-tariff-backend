module PaasS3
  attr_accessor :bucket
  attr_accessor :s3_obj

  def initialize_s3(s3_file_path = nil)
    s3 = service_definition
    @bucket = Aws::S3::Resource.new(
      region: s3['credentials']['aws_region'],
      access_key_id: s3['credentials']['aws_access_key_id'],
      secret_access_key: s3['credentials']['aws_secret_access_key']
    ).bucket(s3['credentials']['bucket_name'])
    @s3_obj = s3_file_path ? @bucket.object(s3_file_path) : @bucket
  end

  def service_definition
    vcap_services = JSON.parse(ENV.fetch('VCAP_SERVICES', dev_services.to_json))
    raise 'no `aws-s3-bucket` was found.' unless vcap_services['aws-s3-bucket']

    services = vcap_services['aws-s3-bucket'].select do |b|
      (b['instance_name'] == instance_name) &&
        (b['label'] == 'aws-s3-bucket')
    end
    services.first
  end

  def dev_services
    {
      "aws-s3-bucket": [
        {
          "instance_name": 'tariff-pdf-dev',
          "label": 'aws-s3-bucket',
          "credentials": {
            "aws_access_key_id": ENV['AWS_PDF_ACCESS_KEY_ID'],
            "aws_region": ENV['AWS_PDF_REGION'],
            "aws_secret_access_key": ENV['AWS_PDF_SECRET_ACCESS_KEY'],
            "bucket_name": ENV['AWS_PDF_BUCKET_NAME'],
            "deploy_env": ''
          }
        }
      ]
    }
  end

  def instance_name
    ENV.fetch('PAAS_S3_SERVICE_NAME', 'tariff-pdf')
  end
end
