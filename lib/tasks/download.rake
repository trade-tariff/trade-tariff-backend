require 'zip'

namespace :tariff do
  namespace :download do
    desc 'Download all Taric files from production AWS S3'
    task taric: %w[environment] do
      s3 = Aws::S3::Resource.new
      files = taric_files(s3)
      s3 = Aws::S3::Client.new
      files.each do |key|
        next unless proceed_with_download?(key)

        File.open(filename(key), 'wb') do |file|
          s3.get_object(bucket: s3_bucket, key: key) do |chunk|
            file.write(chunk)
          end
        end

        if TradeTariffBackend.use_cds?
          extract_file(filename(key)) if key.include?('.zip')
        end
      end
    end

    desc 'Download all CHIEF files from production AWS S3'
    task chief: %w[environment] do
      s3 = Aws::S3::Resource.new
      files = s3.bucket('tariff-production')
                .objects(prefix: 'data/chief/')
                .collect(&:key)
                .delete_if { |o| o.to_s !~ /\.txt$/ }
      s3 = Aws::S3::Client.new
      files.each do |key|
        File.open(key, 'wb') do |file|
          s3.get_object(bucket: 'tariff-production', key: key) do |chunk|
            file.write(chunk)
          end
        end
      end
    end

    desc 'Download all measures log files from development AWS S3'
    task measures_log: %w[environment] do
      s3 = Aws::S3::Resource.new
      files = s3.bucket('tariff-dev')
                .objects(prefix: 'data/measures/')
                .collect(&:key)
                .delete_if { |o| o.to_s !~ /\.txt$/ }
      s3 = Aws::S3::Client.new
      files.each do |key|
        File.open(key, 'wb') do |file|
          s3.get_object(bucket: 'tariff-dev', key: key) do |chunk|
            file.write(chunk)
          end
        end
      end
    end

    def taric_files(s3)
      if TradeTariffBackend.use_cds?
        s3.bucket(s3_bucket)
          .objects
          .collect(&:key)
          .delete_if { |o| o.to_s !~ /\.zip$/ }
      else
        s3.bucket(s3_bucket)
          .objects(prefix: 'data/taric/')
          .collect(&:key)
          .delete_if { |o| o.to_s !~ /\.xml$/ }
      end
    end

    def s3_bucket
      TradeTariffBackend.use_cds? ? 'cds-taric-dump' : 'tariff-production'
    end

    def filename(key)
      TradeTariffBackend.use_cds? ? 'data/taric/' + key : key
    end

    def extract_file(filepath)
      system("mv #{filepath} #{filepath.gsub('.zip', '.gz')}")
      filepath = filepath.gsub('.zip', '.gz')
      command = "gunzip #{filepath}"

      system(command)
      filename = filepath.gsub('.gz', '')
      system("mv #{filename} #{filename}.xml")
    end
  end

  def proceed_with_download?(filename)
    return true unless TradeTariffBackend.use_cds?

    !TariffSynchronizer::TaricUpdate.find(filename: filename[0, 30]).present?
  end
end
