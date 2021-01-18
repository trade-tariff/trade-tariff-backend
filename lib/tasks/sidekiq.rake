namespace :sidekiq do
  require 'sidekiq/api'

  desc "Get status of batch. You must supply a :bid (batch id), e.g. `rake sidekiq:status['BYUxWr4GbojwaQ']`. Batch ID may be found in the Sidekiq::Worker, e.g., `rake sidekiq:workers`"
  task :status, [:bid] do |_task, args|
    exit unless args[:bid]
    status = Sidekiq::Batch::Status.new(args[:bid])
    puts 'batch:        ' + args[:bid]
    puts 'total:        ' + status.total.to_s # jobs in the batch => 97
    puts 'failures:     ' + status.failures.to_s # failed jobs so far => 5
    puts 'pending:      ' + status.pending.to_s # jobs which have not succeeded yet => 17
    puts 'created_at:   ' + status.created_at.to_s # => 2012-09-04 21:15:05 -0700
    puts 'complete?:    ' + status.complete?.to_s # if all jobs have executed at least once => false
    puts 'failure_info: ' + status.failure_info.inspect # an array of failed jobs
    puts 'data:         ' + status.data.inspect # a hash of data about the batch which can easily be converted to JSON for javascript usage
  end

  desc "Print a list of current active worker set for all Sidekiq processes. A 'worker' is defined as a thread currently processing a job"
  task :workers do
    Sidekiq::Workers.new.each do |_process_id, _thread_id, work|
      puts work
    end
  end

  desc "List jobs on a queue. You may provide a queue name, e.g., `rake sidekiq:queue['sync']`, or leave blank for the 'default' queue."
  task :queue, [:queue] do |_task, args|
    q = args[:queue] || 'default'
    queue = Sidekiq::Queue.new(q)
    puts "queue: #{queue.name}"
    puts 'jobs:'
    queue.each do |job|
      puts job.item.inspect
    end
  end

  desc 'Info about the current set of Sidekiq processes running'
  task :processes do
    Sidekiq::ProcessSet.new.each do |process|
      puts process.inspect
    end
  end

  desc 'Various stats about the Sidekiq installation'
  task :stats do
    puts Sidekiq::Stats.new.inspect
  end

  desc 'Show all scheduled jobs in chronologically-sorted order'
  task :scheduled do
    Sidekiq::ScheduledSet.new.each do |job|
      puts job.inspect
    end
  end

  desc 'Gets the current schedule'
  task :get_schedule do
    puts Sidekiq.get_schedule
  end

  desc "Dynamically creates or updates the current schedule for `RunChapterPdfWorker`. Provide a crontab string as an argument, e.g., `rake sidekiq:set_schedule['0 23 * * *']`"
  task :set_schedule, [:cron_string] do |_task, args|
    Sidekiq.set_schedule('RunChapterPdfWorker',
                         cron: args[:cron_string],
                         class: 'RunChapterPdfWorker',
                         description: 'RunChapterPdfWorker produces a printable Trade Tariff PDF.')
    puts Sidekiq.get_schedule
  end

  desc "CAUTION! Clear all of this app's Sidekiq queues from Redis (destructive)."
  task :clear_queue do
    Sidekiq.redis(&:flushdb)
  end
end
