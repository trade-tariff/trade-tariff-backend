RSpec.describe SpellingCorrector::FileUpdaterService do
  include_context 'with a stubbed s3 bucket'

  describe '#call' do
    subject(:upload_file) { described_class.new.call }

    before do
      allow(s3_bucket).to receive(:put_object).and_call_original

      allow(SpellingCorrector::Loaders::Initial).to receive(:new).and_call_original
      allow(SpellingCorrector::Loaders::Synonyms).to receive(:new).and_call_original
      allow(SpellingCorrector::Loaders::Descriptions).to receive(:new).and_call_original
      allow(SpellingCorrector::Loaders::References).to receive(:new).and_call_original
      allow(SpellingCorrector::Loaders::Intercepts).to receive(:new).and_call_original
      allow(SpellingCorrector::Loaders::StopWords).to receive(:new).and_call_original

      upload_file
    end

    # rubocop:disable RSpec/MultipleExpectations
    it 'writes valid content to the correct object' do
      expect(s3_bucket).to have_received(:put_object) do |args|
        expect(args[:key]).to eq('spelling-corrector/spelling-model.txt')
        expect(args[:body]).to be_a(StringIO)
        expect(args[:body].each_line.first).to eq("tree 387\n")
      end
    end
    # rubocop:enable RSpec/MultipleExpectations

    it { expect(SpellingCorrector::Loaders::Initial).to have_received(:new) }
    it { expect(SpellingCorrector::Loaders::Synonyms).to have_received(:new) }
    it { expect(SpellingCorrector::Loaders::Descriptions).to have_received(:new) }
    it { expect(SpellingCorrector::Loaders::References).to have_received(:new) }
    it { expect(SpellingCorrector::Loaders::Intercepts).to have_received(:new) }
    it { expect(SpellingCorrector::Loaders::StopWords).to have_received(:new) }
  end
end
