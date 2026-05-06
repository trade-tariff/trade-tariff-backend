FactoryBot.define do
  factory :customs_tariff_update do
    sequence(:version) { |n| "1.#{n}" }
    validity_start_date { Time.zone.today }
    status { CustomsTariffUpdate::PENDING }
    source_url { 'https://assets.publishing.service.gov.uk/media/abc123/UKGT_1.30.docx' }
    s3_path { "data/customs_tariff_documents/UKGT_#{version}.docx" }
    file_checksum { SecureRandom.hex(32) }
    document_created_on { Time.zone.today }

    trait :approved do
      status { CustomsTariffUpdate::APPROVED }
    end

    trait :rejected do
      status { CustomsTariffUpdate::REJECTED }
    end

    trait :failed do
      status { CustomsTariffUpdate::FAILED }
      import_error { 'Parsing failed: unexpected document structure' }
    end
  end

  factory :customs_tariff_chapter_note do
    association :customs_tariff_update
    sequence(:chapter_id) { |n| sprintf('%02d', n % 99 + 1) }
    content { 'This chapter covers all live animals.' }
    status { CustomsTariffChapterNote::PENDING }

    after(:build) do |note|
      note.customs_tariff_update_version = note.customs_tariff_update.version
    end

    trait :approved do
      status { CustomsTariffChapterNote::APPROVED }
      validity_start_date { Time.zone.today }
    end

    trait :rejected do
      status { CustomsTariffChapterNote::REJECTED }
    end
  end

  factory :customs_tariff_section_note do
    association :customs_tariff_update
    sequence(:section_id) { |n| (n % 21) + 1 }
    content { 'Any reference in this section to a particular genus or species of an animal includes a reference to the young of that genus or species.' }
    status { CustomsTariffSectionNote::PENDING }

    after(:build) do |note|
      note.customs_tariff_update_version = note.customs_tariff_update.version
    end

    trait :approved do
      status { CustomsTariffSectionNote::APPROVED }
      validity_start_date { Time.zone.today }
    end

    trait :rejected do
      status { CustomsTariffSectionNote::REJECTED }
    end
  end

  factory :customs_tariff_general_rule do
    association :customs_tariff_update
    sequence(:rule_label, &:to_s)
    content { 'Classification shall be determined according to the terms of the headings.' }
    status { CustomsTariffGeneralRule::PENDING }

    after(:build) do |rule|
      rule.customs_tariff_update_version = rule.customs_tariff_update.version
    end

    trait :approved do
      status { CustomsTariffGeneralRule::APPROVED }
      validity_start_date { Time.zone.today }
    end

    trait :rejected do
      status { CustomsTariffGeneralRule::REJECTED }
    end
  end
end
