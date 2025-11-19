RSpec.describe PublicUsers::Subscription do
  describe 'associations' do
    it 'has the correct associations', :aggregate_failures do
      t = described_class.association_reflections[:user]
      expect(t[:type]).to eq(:many_to_one)

      t = described_class.association_reflections[:subscription_type]
      expect(t[:type]).to eq(:many_to_one)
    end
  end

  describe '#unsubscribe' do
    let(:subscription) { create(:user_subscription) }
    let(:user) { subscription.user }

    before do
      allow(PublicUsers::ActionLog).to receive(:create)
      allow(user).to receive(:soft_delete!)
    end

    it 'deactivates the subscription' do
      expect { subscription.unsubscribe }.to change { subscription.reload.active }.from(true).to(false)
    end

    it 'logs the unsubscribe action' do
      subscription.unsubscribe
      expect(PublicUsers::ActionLog).to have_received(:create).with(user_id: user.id, action: PublicUsers::ActionLog::UNSUBSCRIBED)
    end

    it 'soft deletes the user' do
      subscription.unsubscribe
      expect(user).to have_received(:soft_delete!)
    end

    context 'when the subscription is already inactive' do
      before { subscription.update(active: false) }

      it 'does not log an unsubscribe action' do
        subscription.unsubscribe
        expect(PublicUsers::ActionLog).not_to have_received(:create).with(user_id: user.id, action: PublicUsers::ActionLog::UNSUBSCRIBED)
      end
    end
  end

  describe 'metadata accessors' do
    let(:subscription) { create(:user_subscription) }
    let(:metadata) { { commodity_codes: %w[1234567890 1234567891] } }

    describe '#set_metadata_key' do
      context 'when metadata is nil' do
        let(:subscription) { create(:user_subscription, metadata: nil) }

        it 'creates new metadata with the key-value pair' do
          subscription.set_metadata_key('new_key', 'new_value')
          subscription.refresh

          expect(subscription.metadata).to eq({ 'new_key' => 'new_value' })
        end

        it 'handles array values' do
          subscription.set_metadata_key('codes', %w[123 456 789])
          subscription.refresh

          expect(subscription.metadata).to eq({ 'codes' => %w[123 456 789] })
        end
      end

      context 'when metadata already exists' do
        let(:initial_metadata) { { 'existing_key' => 'existing_value', 'array_key' => %w[1 2 3] } }
        let(:subscription) { create(:user_subscription, metadata: initial_metadata) }

        it 'updates the specified key without affecting other keys' do
          subscription.set_metadata_key('existing_key', 'updated_value')
          subscription.refresh

          expect(subscription.metadata).to eq({
            'existing_key' => 'updated_value',
            'array_key' => %w[1 2 3],
          })
        end

        it 'adds new keys while preserving existing ones' do
          subscription.set_metadata_key('new_key', 'new_value')
          subscription.refresh

          expect(subscription.metadata).to eq({
            'existing_key' => 'existing_value',
            'array_key' => %w[1 2 3],
            'new_key' => 'new_value',
          })
        end

        it 'can update array values' do
          subscription.set_metadata_key('array_key', %w[4 5 6])
          subscription.refresh

          expect(subscription.metadata).to eq({
            'existing_key' => 'existing_value',
            'array_key' => %w[4 5 6],
          })
        end

        it 'can set complex nested values' do
          complex_value = { 'nested' => { 'deep' => 'value' }, 'array' => [1, 2, 3] }
          subscription.set_metadata_key('complex_key', complex_value)
          subscription.refresh

          expect(subscription.metadata['complex_key']).to eq(complex_value)
        end
      end
    end

    describe '#get_metadata_key' do
      let(:metadata) { { 'string_key' => 'string_value', 'array_key' => %w[1 2 3], 'nil_key' => nil } }
      let(:subscription) { create(:user_subscription, metadata: metadata) }

      it 'returns the value for an existing key' do
        expect(subscription.get_metadata_key('string_key')).to eq('string_value')
      end

      it 'returns array values correctly' do
        expect(subscription.get_metadata_key('array_key')).to eq(%w[1 2 3])
      end

      it 'returns nil for non-existent keys' do
        expect(subscription.get_metadata_key('non_existent_key')).to be_nil
      end

      it 'returns nil for keys explicitly set to nil' do
        expect(subscription.get_metadata_key('nil_key')).to be_nil
      end

      context 'when metadata is nil' do
        let(:subscription) { create(:user_subscription, metadata: nil) }

        it 'returns nil for any key' do
          expect(subscription.get_metadata_key('any_key')).to be_nil
        end
      end

      context 'when metadata is empty' do
        let(:subscription) { create(:user_subscription, metadata: {}) }

        it 'returns nil for any key' do
          expect(subscription.get_metadata_key('any_key')).to be_nil
        end
      end
    end
  end

  describe '.scope' do
    describe '.with_subscription_type' do
      before do
        create(:public_user, :with_my_commodities_subscription)
        create(:public_user, :with_active_stop_press_subscription)
      end

      it 'returns subscriptions of type my_commodities' do
        expect(described_class.with_subscription_type(Subscriptions::Type.my_commodities).count).to eq(1)
      end
    end
  end

  describe '#add_targets' do
    let(:subscription) { create(:user_subscription) }
    let(:user) { subscription.user }

    context 'when there is an array of targets and a subscription' do
      let(:targets) do
        [create(:goods_nomenclature, goods_nomenclature_sid: 123),
         create(:goods_nomenclature, goods_nomenclature_sid: 456)]
      end
      let(:existing_targets) do
        [create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: 789, target_type: 'commodity'),
         create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: 321, target_type: 'commodity'),
         create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: 999, target_type: 'measure')]
      end

      before do
        existing_targets.each(&:save)
        subscription.add_targets(targets: targets, target_type: 'commodity')
      end

      it 'only deletes existing targets for the selected subscription type' do
        target_ids = subscription.subscription_targets_dataset.map(&:target_id)

        expect(target_ids).not_to include(789, 321)
        expect(target_ids).to include(999)
      end

      it 'adds the target sids for the subscription type' do
        expect(subscription.subscription_targets_dataset.commodities.map(&:target_id))
       .to match_array(targets.map(&:goods_nomenclature_sid))
      end
    end

    context 'when there are no targets' do
      let(:targets) { [] }

      before do
        subscription.add_targets(targets: targets, target_type: 'commodity')
      end

      it 'does not add any targets' do
        expect(subscription.subscription_targets.count).to eq(0)
      end
    end
  end
end
