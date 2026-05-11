RSpec.describe DescriptionIntercepts::TemplateImporter do
  let(:templates) do
    {
      'vague' => {
        'label' => 'Vague term',
        'description' => 'Use when the term is too broad to classify safely.',
        'attributes' => {
          'escalate_to_webchat' => false,
          'excluded' => true,
          'filter_prefixes' => [],
          'guidance_level' => 'info',
          'guidance_location' => 'interstitial',
          'message_header' => 'Placeholder guidance heading',
          'message' => 'This is too vague. Please be better at classification',
          'sources' => %w[guided_search fpo_search],
        },
      },
      'escalate' => {
        'label' => 'Escalate',
        'description' => 'Escalate to webchat.',
        'attributes' => {
          'escalate_to_webchat' => true,
          'excluded' => false,
          'filter_prefixes' => [],
          'guidance_level' => nil,
          'guidance_location' => nil,
          'message_header' => nil,
          'message' => nil,
          'sources' => %w[guided_search],
        },
      },
    }
  end

  before do
    create(:admin_configuration, name: 'description_intercept_templates', config_type: 'object_template', value: templates)
  end

  describe '#call' do
    it 'creates intercepts from template rows' do
      result = described_class.new(csv_content: "term,template\nGift,vague\n").call

      expect(result).to be_success
      expect(result.created_count).to eq(1)
      intercept = DescriptionIntercept.first(term: 'gift')
      expect(intercept).to have_attributes(
        excluded: true,
        guidance_level: 'info',
        guidance_location: 'interstitial',
        message_header: 'Placeholder guidance heading',
        message: 'This is too vague. Please be better at classification',
      )
      expect(intercept.sources).to eq(%w[guided_search fpo_search])
    end

    it 'creates intercepts with aliases from template rows' do
      result = described_class.new(csv_content: "term,aliases,template\nGift,\"Present,Gifts\",vague\n").call

      expect(result).to be_success
      intercept = DescriptionIntercept.first(term: 'gift')
      expect(intercept.aliases).to eq(%w[present gifts])
    end

    it 'updates existing intercepts by normalised term and preserves aliases' do
      existing = create(:description_intercept, term: 'gift', aliases: Sequel.pg_array(%w[present], :text), excluded: false)

      result = described_class.new(csv_content: "term,template\n Gift ,vague\n").call

      expect(result).to be_success
      expect(result.updated_count).to eq(1)
      existing.reload
      expect(existing.excluded).to be(true)
      expect(existing.aliases).to eq(%w[present])
    end

    it 'clears the existing aliases when the aliases column is present and blank' do
      existing = create(:description_intercept, term: 'gift', aliases: Sequel.pg_array(%w[present], :text), excluded: false)

      result = described_class.new(csv_content: "term,aliases,template\n Gift, ,vague\n").call

      expect(result).to be_success
      expect(existing.reload.aliases).to eq([])
    end

    it 'rejects duplicate search values across terms and aliases before writing' do
      result = described_class.new(csv_content: "term,aliases,template\ngift,present,vague\n Present ,something,vague\n").call

      expect(result).not_to be_success
      expect(result.summary_errors.first[:detail]).to eq('present appears more than once across terms and aliases')
      expect(DescriptionIntercept.count).to eq(0)
    end

    it 'rejects an alias already used by another intercept' do
      create(:description_intercept, term: 'hamper', aliases: Sequel.pg_array(%w[present], :text))

      result = described_class.new(csv_content: "term,aliases,template\ngift,present,vague\n").call

      expect(result).not_to be_success
      expect(result.row_errors.first[:detail]).to eq('gift aliases include a value already used by another description intercept (present)')
      expect(DescriptionIntercept.first(term: 'gift')).to be_nil
    end

    it 'deduplicates invalid template errors' do
      result = described_class.new(csv_content: "term,template\na,foo\nb,baz\nc,foo\nd,bar\n").call

      expect(result).not_to be_success
      expect(result.summary_errors).to include(
        detail: 'foo, baz and bar are not valid templates',
        meta: { code: 'invalid_templates', values: %w[foo baz bar] },
      )
      expect(result.row_errors).to be_empty
    end

    it 'uses a singular invalid template message' do
      result = described_class.new(csv_content: "term,template\na,foo\n").call

      expect(result).not_to be_success
      expect(result.summary_errors).to include(
        detail: 'foo is not a valid template',
        meta: { code: 'invalid_templates', values: %w[foo] },
      )
      expect(result.row_errors).to be_empty
    end

    it 'rejects unknown headers before writing' do
      result = described_class.new(csv_content: "term,template,notes\ngift,vague,nope\n").call

      expect(result).not_to be_success
      expect(result.summary_errors.first[:detail]).to eq('CSV must contain term and template columns, and may include an aliases column')
    end

    it 'rolls back all writes when any row is invalid' do
      result = described_class.new(csv_content: "term,template\ngift,vague\nshoe,missing\n").call

      expect(result).not_to be_success
      expect(DescriptionIntercept.count).to eq(0)
    end
  end
end
