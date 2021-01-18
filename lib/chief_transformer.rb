require 'delegate'
require 'singleton'
require 'date'
require 'sequel-rails'
require 'chief_transformer/candidate_measure'
require 'chief_transformer/processor'
require 'chief_transformer/initial_load_processor'

require 'active_support/notifications'
require 'active_support/log_subscriber'

require 'chief_transformer/logger'
require 'chief_transformer/mailer'
require 'chief_transformer/measures_logger'

class ChiefTransformer
  include Singleton

  class TransformException < StandardError
    attr_reader :original

    def initialize(msg = 'ChiefTransformer::TransformException', original=$!)
      super(msg)
      @original = original
    end
  end

  delegate :instrument, :subscribe, to: ActiveSupport::Notifications

  # Use update mode (the default) to process daily updates. Does not perform
  # pagination, processes MFCMs, TAMEs and TAMFs, merges them and persists.
  #
  # Use initial_load mode to process initial CHIEF load. It performs
  # pagination and does not process TAMEs and TAMFs separately from MFCMs.
  cattr_accessor :work_modes
  self.work_modes = [:update, :initial_load]

  # Number of MFCM entries to process per page. Can't be too high due to
  # memory constraints. Only applicable to initial_load mode.
  mattr_accessor :per_page
  self.per_page = 1000

  def invoke(work_mode = :update, chief = nil)
    instrument('start_transform.chief_transformer', mode: work_mode)

    unless work_mode.in? work_modes
      raise TransformException.new("Invalid work mode, options: #{work_modes}")
    end

    case work_mode
    when :initial_load
      processor = InitialLoadProcessor.new(
        Chief::Mfcm.initial_load.unprocessed, per_page
      )
    when :update
      processor = Processor.new(
        Chief::Mfcm.unprocessed.where(origin: chief.try(:filename)).all,
        Chief::Tame.unprocessed.where(origin: chief.try(:filename)).all
      )
    end

    # Before run:
    # deleting local and S3 version of logs
    ChiefTransformer::MeasuresLogger.delete_logs(chief.try(:filename))

    processor.process

    # After run:
    # upload logs to S3 after each processor run
    ChiefTransformer::MeasuresLogger.upload_to_s3(chief.try(:filename))
  end
end
