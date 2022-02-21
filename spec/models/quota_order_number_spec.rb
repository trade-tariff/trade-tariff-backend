RSpec.describe QuotaOrderNumber do
  context 'with an existing QuotaOrderNumber' do
    let(:quota_order_number) { create(:quota_order_number) }
    let(:definition) { create(:quota_definition, quota_order_number_sid: quota_order_number.quota_order_number_sid) }

    before { definition }

    describe '#quota_definition!' do
      subject { quota_order_number.quota_definition! }

      it { is_expected.to eq(definition) }
    end

    describe '#definition_id' do
      subject { quota_order_number.definition_id }

      it { is_expected.to eq(definition.quota_definition_sid) }
    end
  end

  context 'without a persisted QuotaOrderNumber' do
    context 'when not handled by the RPA' do
      let(:quota_order_number) { described_class.new(quota_order_number_id: '090000') }

      let(:definition) do
        create(:quota_definition, quota_order_number_sid: quota_order_number.quota_order_number_sid)
      end

      describe '#quota_definition!' do
        it 'returns nil' do
          expect(quota_order_number.quota_definition!).to eq(nil)
        end
      end
    end

    context 'when handled by the RPA with start code 0*4*' do
      describe '#quota_definition!' do
        it 'returns nil' do
          (1..9).each do |i|
            quota_order_number = create(:quota_order_number, quota_order_number_id: "0#{i}4504")

            create(:quota_definition, quota_order_number_sid: quota_order_number.quota_order_number_sid)

            expect(quota_order_number.quota_definition!).to eq(nil)
          end
        end
      end
    end
  end

  describe '.with_quota_definitions' do
    subject(:with_quota_definitions) { described_class.with_quota_definitions.map(&:quota_order_number_id) }

    around do |example|
      TimeMachine.now { example.run }
    end

    before do
      create(:quota_order_number, :with_quota_definition, :current, :current_definition, quota_order_number_id: '000001') # target
      create(:quota_order_number, :with_quota_definition, :current, :expired_definition, quota_order_number_id: '000002') # control
      create(:quota_order_number, :with_quota_definition, :expired, :current_definition, quota_order_number_id: '000003') # control
      create(:quota_order_number, :with_quota_definition, :expired, :expired_definition, quota_order_number_id: '000004') # control
    end

    it { is_expected.to eq %w[000001] }
  end

  describe '#definition_id' do
    subject(:definition_id) { create(:quota_order_number, :with_quota_definition, quota_definition_sid: 111).definition_id }

    it { is_expected.to eq(111) }
  end

  describe '#quota_definition_id' do
    subject(:quota_order_number) { create(:quota_order_number) }

    it { expect(quota_order_number.method(:quota_definition_id)).to eq(quota_order_number.method(:definition_id)) }
  end
end
