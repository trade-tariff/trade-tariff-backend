class ImportSearchReferences
  SPLIT_REGEX = /or|OR/.freeze

  HEADING_IDENTITY_REGEX = /(\d{1,2}).(\d{1,2})/.freeze
  CHAPTER_IDENTITY_REGEX = /Chapter (\d{1,2})|Ch (\d{1,2})|^\s{0,}\d{1,2}\s{0,}$/.freeze
  SECTION_IDENTITY_REGEX = /Section\s{1,}(\d{1,2})|section\s{1,}(\d{1,2})/.freeze

  def self.reload(from_file = Rails.root.join('db/green-pages.csv'))
    SearchReference.truncate

    new(from_file).run
  end

  def initialize(data_file)
    @data_file = data_file
  end

  def run
    CSV.foreach(@data_file, col_sep: ';') do |line|
      title, reference = line

      if references_multiple_records?(reference)
        create_multiple_records(title, reference)
      else
        create_record(title, reference)
      end
    end
  end

  private

  def create_record(title, reference)
    SearchReference.create({
      title: title.downcase,
    }.merge(associated_entity(reference)))
  end

  def create_multiple_records(title, reference)
    reference.split(SPLIT_REGEX).map(&:strip).each do |ref|
      create_record(title, ref)
    end
  end

  def associated_entity(reference)
    case reference
    when HEADING_IDENTITY_REGEX
      {
        referenced_id: Heading.by_code("#{Regexp.last_match(1)}#{Regexp.last_match(2)}").first_or_null.short_code,
        referenced_class: 'Heading',
      }
    when CHAPTER_IDENTITY_REGEX
      {
        referenced_id: Chapter.by_code(Regexp.last_match(1)).first_or_null.short_code,
        referenced_class: 'Chapter',
      }
    when SECTION_IDENTITY_REGEX
      {
        referenced_id: Section.where(position: Regexp.last_match(1)).first_or_null.id,
        referenced_class: 'Section',
      }
    else
      {}
    end
  end

  def references_multiple_records?(reference)
    reference =~ SPLIT_REGEX
  end
end
