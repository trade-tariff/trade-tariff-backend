class ReportWorker
  include Sidekiq::Worker

  sidekiq_options retry: false

  def perform(trigger_differences_report = true)
    return if Rails.env.development?

    self.baseline = mem.mb

    Rails.logger.info '=== MEMORY REPORT START ==='
    Rails.logger.info "Baseline memory: #{mem.mb.round(2)} MB"

    profile_report('Commodities')
    profile_report('Basic')
    profile_report('SupplementaryUnits')
    # NOTE: This consumes 2.3 GB of memory and isn't being used so turning off for now
    # profile_report('DeclarableDuties')
    profile_report('Prohibitions')
    profile_report('GeographicalAreaGroups')
    profile_report('CategoryAssessments')

    Rails.logger.info "Final memory: #{mem.mb.round(2)} MB"
    Rails.logger.info '=== MEMORY REPORT END ==='

    schedule_differences_generation if trigger_differences_report
  end

  private

  def generate_differences?
    TradeTariffBackend.uk? && monday?
  end

  def schedule_differences_generation
    # Delays to ensure both XI and UK Report Workers have completed before
    # DifferencesReportWorker executes
    DifferencesReportWorker.perform_in(30.minutes) if generate_differences?
  end

  def monday?
    Time.zone.now.monday?
  end

  attr_accessor :baseline

  def mem
    @mem ||= GetProcessMem.new
  end

  def profile_report(name)
    mem = GetProcessMem.new

    before = mem.mb
    gc_start

    "Reporting::#{name}".constantize.generate

    gc_start
    after = mem.mb

    peak_during = [after, before].max
    delta = peak_during - baseline

    Rails.logger.info "[MEMORY] #{name.ljust(30)} → " \
                      "Peak: #{peak_during.round(2)} MB | " \
                      "Delta: +#{delta.round(2)} MB | " \
                      "Growth from prev: +#{(after - before).round(2)} MB"

    self.baseline = peak_during
  end

  def gc_start
    GC.start(full_mark: true, immediate_sweep: true)
  end
end
