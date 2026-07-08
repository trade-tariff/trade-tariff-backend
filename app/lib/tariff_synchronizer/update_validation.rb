module TariffSynchronizer
  module UpdateValidation
    def check_tariff_updates_failures
      failed = update_type.failed
      if failed.any?
        Instrumentation.failed_updates_detected(filenames: failed.map(&:filename))
        raise FailedUpdatesError
      end
    rescue FailedUpdatesError => e
      notify_slack_app(e)

      raise
    end

    def notify_slack_app(exception)
      SlackNotifierService.call("Error #{exception.class}: #{exception.message}")
    end

    def check_sequence
      if update_type.correct_filename_sequence?
        Instrumentation.sequence_check_passed
      else
        Instrumentation.sequence_check_failed(
          details: 'Wrong sequence between the pending and applied files. Check the admin updates UI.',
        )
        raise FailedUpdatesError, 'Wrong sequence between the pending and applied files. Check the admin updates UI.'
      end
    rescue FailedUpdatesError => e
      notify_slack_app(e)

      raise
    end
  end
end
