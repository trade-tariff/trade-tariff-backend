FactoryBot.define do
  factory :vat_guidance_guide, class: 'VatGuidance::Guide' do
    sequence(:guide_key) { |n| "notice-701-#{n}" }
    sequence(:content_id) { |n| "00000000-0000-4000-8000-#{n.to_s.rjust(12, '0')}" }
  end

  factory :vat_guidance_guide_version, class: 'VatGuidance::GuideVersion' do
    guide { create(:vat_guidance_guide) }
    title { 'VAT Notice 701/1: How VAT affects charities' }
    canonical_path { '/guidance/how-vat-affects-charities-notice-7011' }
    source_url { "https://www.gov.uk#{canonical_path}" }
    language { 'en' }
    public_updated_at { Time.zone.parse('2026-07-30 09:00:00 UTC') }
    captured_at { Time.zone.parse('2026-07-30 10:00:00 UTC') }
    sequence(:body_sha256) { |n| Digest::SHA256.hexdigest("guide body #{n}") }
    sections do
      Sequel.pg_jsonb_wrap(
        [
          {
            'section_key' => 'overview',
            'heading' => 'Overview',
            'content' => 'This notice explains how VAT affects charities.',
            'content_sha256' => Digest::SHA256.hexdigest('This notice explains how VAT affects charities.'),
          },
        ],
      )
    end
    capture_metadata { Sequel.pg_jsonb_wrap({}) }
  end
end
