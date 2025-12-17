class Appendix5aPopulatorService
  def call
    Rails.logger.info 'Populating Appendix 5a'

    Appendix5a.unrestrict_primary_key
    Appendix5a.db.transaction do
      added_guidance.each(&:save)
      changed_guidance.each(&:save)
      removed_guidance.each(&:destroy)
    end
    Appendix5a.restrict_primary_key

    notify

    Rails.logger.info 'Finished populating Appendix 5a'
  end

  private

  def removed_guidance
    @removed_guidance ||= begin
      removed_document_codes = existing_document_codes - new_guidance.keys

      existing_guidance.select do |guidance|
        removed_document_codes.include?(guidance.document_code)
      end
    end
  end

  def added_guidance
    @added_guidance ||= begin
      added_document_codes = new_guidance.keys - existing_document_codes

      added_document_codes.map do |document_code|
        guidance = new_guidance[document_code]

        certificate_type_code = document_code[0]
        certificate_code = document_code[1..]
        cds_guidance = guidance['guidance_cds']

        Appendix5a.new(
          certificate_type_code:,
          certificate_code:,
          cds_guidance:,
        )
      end
    end
  end

  def changed_guidance
    @changed_guidance ||= begin
      changed_document_codes = new_guidance.keys & existing_document_codes

      changed_document_codes.each_with_object([]) do |document_code, acc|
        existing_guidance.each do |guidance|
          next unless guidance.document_code == document_code

          guidance.cds_guidance = new_guidance[document_code]['guidance_cds']

          if guidance.column_changes.any?
            acc << guidance
          end
        end
      end
    end
  end

  def existing_document_codes
    @existing_document_codes ||= existing_guidance.map(&:document_code)
  end

  def new_guidance
    @new_guidance ||= Appendix5a.fetch_latest
  end

  def existing_guidance
    @existing_guidance ||= Appendix5a.all
  end

  def notify
    return if no_guidance_changes?

    message = "Appendix 5a has been updated with #{added_guidance.count} new, "
    message += "#{changed_guidance.count} changed and "
    message += "#{removed_guidance.count} removed guidance documents"

    Rails.logger.info message

    SlackNotifierService.call(message)
    Appendix5aMailer.appendix5a_notify_message(added_guidance.count,
                                               changed_guidance.count,
                                               removed_guidance.count)
                                              .deliver_now
  end

  def no_guidance_changes?
    added_guidance.empty? && changed_guidance.empty? && removed_guidance.empty?
  end
end
