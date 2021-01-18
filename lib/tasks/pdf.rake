namespace :pdf do
  desc 'Removes all log files related to PDF generation'
  task clear_all_logs: :environment do
    Dir.glob("#{Rails.root}/log/pdf/*.log").each { |file| File.delete(file) }
    puts 'Removed all log files related to PDF generation.'
  end

  desc 'Removes all PDF files in the local file system (there should be none if everything processed without error)'
  task clear_all_pdfs: :environment do
    ["#{Rails.root}/public/pdf/tariff/*.pdf", "#{Rails.root}/public/pdf/tariff/chapters/*.pdf"].each do |filter|
      Dir.glob(filter).each { |file| File.delete(file) }
    end
    puts 'Removed all PDF files in the local file system.'
  end

  desc 'Retrieves the latest PDF generation log file and prints it to STDOUT'
  task latest_log: :environment do
    logfile = Dir.glob("#{Rails.root}/log/pdf/*.log").max_by { |f| File.mtime(f) }
    puts
    puts logfile
    puts
    IO.foreach(logfile) { |x| puts x }
    puts
  end
end
