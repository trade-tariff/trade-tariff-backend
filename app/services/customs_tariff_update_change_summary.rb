class CustomsTariffUpdateChangeSummary
  def initialize(update)
    @update = update
  end

  def call
    {
      chapter_ids: changed_ids(CustomsTariffChapterNote, :chapter_id, previous_chapter_notes),
      section_ids: changed_ids(CustomsTariffSectionNote, :section_id, previous_section_notes),
    }
  end

private

  def changed_ids(note_class, id_attribute, baseline_by_id)
    note_class
      .where(customs_tariff_update_version: @update.version)
      .all
      .select { |note| changed?(note, id_attribute, baseline_by_id) }
      .map(&id_attribute)
      .sort
  end

  def changed?(note, id_attribute, baseline_by_id)
    baseline = baseline_by_id[note.public_send(id_attribute)]
    return true if baseline.nil?

    VersionDiffService.new(
      note.class.name,
      { 'content' => baseline.content },
      { 'content' => note.content },
    ).call.present?
  end

  def previous_update
    start_date = @update.validity_start_date

    @previous_update ||= CustomsTariffUpdate
      .imported
      .where { validity_start_date < start_date }
      .order(Sequel.desc(:validity_start_date))
      .first
  end

  def previous_chapter_notes
    return {} unless previous_update

    CustomsTariffChapterNote.where(customs_tariff_update_version: previous_update.version).all.index_by(&:chapter_id)
  end

  def previous_section_notes
    return {} unless previous_update

    CustomsTariffSectionNote.where(customs_tariff_update_version: previous_update.version).all.index_by(&:section_id)
  end
end
