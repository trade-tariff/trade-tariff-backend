s3_bucket_name = ENV['SPELLING_CORRECTOR_BUCKET_NAME']
running_in_aws = ENV['ECS_AGENT_URI'].present?
credentials_loaded = ENV['AWS_PROFILE'].present? || (ENV['AWS_SECRET_ACCESS_KEY'].present? && ENV['AWS_ACCESS_KEY_ID'])

if s3_bucket_name.present?
  if Rails.env.development? && ENV.key?('AWS_ENDPOINT')
    unless Aws::S3::Resource.new(endpoint: ENV['AWS_ENDPOINT']).bucket(s3_bucket_name).exists?
      Aws::S3::Resource.new(endpoint: ENV['AWS_ENDPOINT']).create_bucket({ bucket: s3_bucket_name })
    end
    Aws::S3::Resource.new(endpoint: ENV['AWS_ENDPOINT']).bucket(s3_bucket_name)
  elsif Rails.env.test?
    s3_bucket = Aws::S3::Resource.new(stub_responses: true).bucket(s3_bucket_name)
  elsif running_in_aws || credentials_loaded
    s3_bucket = Aws::S3::Resource.new.bucket(s3_bucket_name)
  else
    Rails.logger.warn 'AWS credentials missing, or not running on AWS.'
  end

  Rails.application.config.spelling_corrector_s3_bucket = s3_bucket
end
