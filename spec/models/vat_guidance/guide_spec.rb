RSpec.describe VatGuidance::Guide do
  it 'stores a stable guide identity with immutable versions' do
    guide = create(:vat_guidance_guide)
    version = create(:vat_guidance_guide_version, guide:)

    expect(guide.versions).to contain_exactly(version)
  end

  it 'rejects changes to the stable identity after insert' do
    guide = create(:vat_guidance_guide)

    expect {
      guide.update(guide_key: 'replacement-key')
    }.to raise_error(Sequel::ValidationFailed, /immutable/)
  end
end
