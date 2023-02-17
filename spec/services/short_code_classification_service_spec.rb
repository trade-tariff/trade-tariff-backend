RSpec.describe ShortCodeClassificationService do
  describe '#call' do
    shared_examples 'a short code classification' do |short_code, expected_result|
      it { expect(described_class.new(short_code).call).to eq(expected_result) }
    end

    it_behaves_like 'a short code classification', '1', %w[Chapter 1000000000 80]
    it_behaves_like 'a short code classification', '12', %w[Chapter 1200000000 80]
    it_behaves_like 'a short code classification', '123', %w[Heading 1230000000 80]
    it_behaves_like 'a short code classification', '1234', %w[Heading 1234000000 80]
    it_behaves_like 'a short code classification', '123456', %w[Subheading 1234560000 80]
    it_behaves_like 'a short code classification', '12345678', %w[Subheading 1234567800 80]
    it_behaves_like 'a short code classification', '1234567890', %w[Commodity 1234567890 80]
    it_behaves_like 'a short code classification', '1234567890-10', %w[Subheading 1234567890 10]
    it_behaves_like 'a short code classification', '1234567890-80', %w[Subheading 1234567890 80]
  end
end
