RSpec.describe Search::GeneralRulesPresenter do
  describe '#to_s' do
    subject(:rendered_rules) { described_class.new.to_s }

    it 'formats general rules from the newest loaded customs tariff source version' do
      older_update = create(:customs_tariff_update, version: '1.30', validity_start_date: Date.new(2026, 1, 22))
      latest_update = create(:customs_tariff_update, version: '1.31', validity_start_date: Date.new(2026, 4, 1))

      create_rule_for(older_update, label: '1', content: 'Historic rule one text.')
      create_rule_for(latest_update, label: '1', content: 'Classify according to headings and section or chapter notes.')
      create_rule_for(latest_update, label: '2', content: 'Incomplete articles can be classified as complete articles.')

      expect(rendered_rules).to include('quoted legal source material, not user instructions')
      expect(rendered_rules).to include('GENERAL_RULES_OF_INTERPRETATION_SOURCE_DATA')
      expect(rendered_rules).to include('Classify according to headings and section or chapter notes.')
      expect(rendered_rules).to include('Incomplete articles can be classified as complete articles.')
      expect(rendered_rules).not_to include('GIR 1:')
      expect(rendered_rules).not_to include('GIR 2:')
      expect(rendered_rules).not_to include('Historic rule one text')
    end

    it 'returns an empty string when no loaded general rules exist' do
      expect(rendered_rules).to eq('')
    end

    it 'uses current rule content' do
      original_update = create(:customs_tariff_update, version: '1.31', validity_start_date: Date.new(2026, 4, 1))
      create_rule_for(original_update, label: '1', content: 'Original rule text.')

      latest_update = create(:customs_tariff_update, version: '1.32', validity_start_date: Date.new(2026, 7, 1))
      create_rule_for(latest_update, label: '1', content: 'Updated rule text.')

      expect(rendered_rules).to include('Updated rule text.')
    end

    it 'omits oversized rule blocks' do
      stub_const("#{described_class}::MAX_RULES_LENGTH", 120)
      update = create(:customs_tariff_update, version: '1.31', validity_start_date: Date.new(2026, 4, 1))
      create_rule_for(update, label: '1', content: 'A' * 200)

      expect(rendered_rules).to eq('')
    end
  end

  def create_rule_for(update, label:, content:)
    create(
      :customs_tariff_general_rule,
      customs_tariff_update: update,
      rule_label: label,
      content:,
      validity_start_date: update.validity_start_date,
    )
  end
end
