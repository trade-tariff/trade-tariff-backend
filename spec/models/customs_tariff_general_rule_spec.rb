RSpec.describe CustomsTariffGeneralRule do
  describe '.latest_rules' do
    it 'returns rules for the latest actual update version' do
      older_update = create(:customs_tariff_update, version: '1.30', validity_start_date: Date.new(2026, 1, 22))
      latest_update = create(:customs_tariff_update, version: '1.31', validity_start_date: Date.new(2026, 4, 1))
      failed_update = create(:customs_tariff_update, :failed, version: '1.32', validity_start_date: Date.new(2026, 6, 1))
      future_update = create(:customs_tariff_update, version: '1.33', validity_start_date: Date.new(2026, 8, 1))

      historic_rule = create(:customs_tariff_general_rule, customs_tariff_update: older_update, rule_label: '1', content: 'Historic rule text.', validity_start_date: older_update.validity_start_date)
      second_rule = create(:customs_tariff_general_rule, customs_tariff_update: latest_update, rule_label: '2', content: " Second rule text.\n\nWith spacing. ", validity_start_date: latest_update.validity_start_date)
      first_rule = create(:customs_tariff_general_rule, customs_tariff_update: latest_update, rule_label: '1', content: 'First rule text.', validity_start_date: latest_update.validity_start_date)
      failed_rule = create(:customs_tariff_general_rule, customs_tariff_update: failed_update, rule_label: '1', content: 'Failed update text.', validity_start_date: failed_update.validity_start_date)
      future_rule = create(:customs_tariff_general_rule, customs_tariff_update: future_update, rule_label: '1', content: 'Future rule text.', validity_start_date: future_update.validity_start_date)

      rules = TimeMachine.at(Date.new(2026, 7, 1)) { described_class.latest_rules }

      expect(rules).to eq([first_rule, second_rule])
      expect(rules).not_to include(historic_rule)
      expect(rules).not_to include(failed_rule)
      expect(rules).not_to include(future_rule)
    end

    it 'returns an empty array when no rules are loaded' do
      expect(described_class.latest_rules).to eq([])
    end
  end
end
