RSpec.describe EnquiryForm::SubmissionHelper, type: :helper do
  describe '#create_reference_number' do
    let(:charset) { described_class::CHARSET }

    it 'returns a string of default length 8' do
      ref = helper.create_reference_number
      expect(ref.length).to eq(8)
    end

    it 'only contains characters from CHARSET' do
      ref = helper.create_reference_number(8)
      expect(ref.chars).to all(be_in(charset))
    end

    it 'does not contain O or I' do
      ref = helper.create_reference_number(50)
      expect(ref).not_to match(/[OI]/)
    end

    it 'produces different values on subsequent calls' do
      ref1 = helper.create_reference_number
      ref2 = helper.create_reference_number
      expect(ref1).not_to eq(ref2)
    end
  end
end
