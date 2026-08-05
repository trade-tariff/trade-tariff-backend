RSpec.describe VatGuidance::GuideVersion do
  describe 'content identity' do
    it 'enforces one body hash per guide at the database boundary' do
      existing = create(:vat_guidance_guide_version)

      expect {
        described_class.dataset.insert(existing.values.except(:id))
      }.to raise_error(Sequel::UniqueConstraintViolation)
    end

    it 'allows different guides to capture the same body hash' do
      existing = create(:vat_guidance_guide_version)

      expect {
        create(:vat_guidance_guide_version, body_sha256: existing.body_sha256)
      }.to change(described_class, :count).by(1)
    end
  end

  describe 'captured content' do
    it 'stores ordered sections as one closed JSON object' do
      version = create(:vat_guidance_guide_version)

      expect(version.reload.sections).to contain_exactly(
        a_hash_including(
          'section_key' => 'overview',
          'heading' => 'Overview',
        ),
      )
    end

    it 'rejects unknown section fields' do
      version = build(
        :vat_guidance_guide_version,
        sections: [
          {
            'section_key' => 'overview',
            'content' => 'Captured content',
            'unexpected' => true,
          },
        ],
      )

      expect(version).not_to be_valid
      expect(version.errors[:sections]).to include(/unknown fields: unexpected/)
    end

    it 'requires unique stable section keys' do
      content_sha256 = Digest::SHA256.hexdigest('Captured content')
      version = build(
        :vat_guidance_guide_version,
        sections: [
          { 'section_key' => 'overview', 'content_sha256' => content_sha256 },
          { 'section_key' => 'overview', 'content_sha256' => content_sha256 },
        ],
      )

      expect(version).not_to be_valid
      expect(version.errors[:sections]).to include('must have unique section keys')
    end

    it 'requires section keys to be non-empty strings' do
      version = build(
        :vat_guidance_guide_version,
        sections: [{ 'section_key' => 123, 'content' => 'Captured content' }],
      )

      expect(version).not_to be_valid
      expect(version.errors[:sections]).to include('entry 1 section_key must be a non-empty string')
    end

    it 'rejects non-string section content fields' do
      version = build(
        :vat_guidance_guide_version,
        sections: [{ 'section_key' => 'overview', 'heading' => 123, 'content' => true }],
      )

      expect(version).not_to be_valid
      expect(version.errors[:sections]).to include(
        'entry 1 heading must be a string',
        'entry 1 content must be a string',
      )
    end

    it 'rejects non-string content hashes without raising an error' do
      version = build(
        :vat_guidance_guide_version,
        sections: [{ 'section_key' => 'overview', 'content_sha256' => 123 }],
      )

      expect(version).not_to be_valid
      expect(version.errors[:sections]).to include(
        'entry 1 content_sha256 must be a lowercase SHA-256 digest',
      )
    end

    it 'requires the content hash to match the captured content' do
      version = build(
        :vat_guidance_guide_version,
        sections: [
          {
            'section_key' => 'overview',
            'content' => 'Captured content',
            'content_sha256' => Digest::SHA256.hexdigest('Different content'),
          },
        ],
      )

      expect(version).not_to be_valid
      expect(version.errors[:sections]).to include('entry 1 content_sha256 must match content')
    end
  end

  describe 'immutability' do
    let(:version) { create(:vat_guidance_guide_version) }

    it 'rejects model updates after capture' do
      expect {
        version.update(title: 'changed after capture')
      }.to raise_error(Sequel::ValidationFailed, /immutable/)
    end

    it 'rejects model deletion after capture' do
      expect {
        version.destroy
      }.to raise_error(Sequel::ValidationFailed, /immutable/)
    end

    it 'rejects direct database updates after capture' do
      expect {
        described_class.where(id: version.id).update(title: 'changed directly')
      }.to raise_error(Sequel::DatabaseError, /immutable/)
    end
  end
end
