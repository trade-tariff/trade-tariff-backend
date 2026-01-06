RSpec.describe PublicUsers::User do
  let(:user) { create(:public_user) }

  describe 'associations' do
    it 'has a subscriptions association' do
      t = described_class.association_reflections[:subscriptions]
      expect(t[:type]).to eq(:one_to_many)
    end

    it 'has a preferences association' do
      t = described_class.association_reflections[:preferences]
      expect(t[:type]).to eq(:one_to_one)
    end
  end

  describe 'when creating' do
    it 'creates a preferences record' do
      expect(user.preferences).not_to be_nil
    end

    it 'creates an action log' do
      expect(user.action_logs.first.action).to eq PublicUsers::ActionLog::REGISTERED
    end
  end

  describe 'email attribute' do
    before do
      allow(IdentityApiClient).to receive(:get_email).and_return('retrieved@email.com')
    end

    it 'has a settable virtual email attribute' do
      user.email = 'example@test.com'
      expect(user.email).to eq 'example@test.com'
    end

    it 'calls api client to get email if not set' do
      expect(user.email).to eq 'retrieved@email.com'
    end
  end

  describe '#stop_press_subscription' do
    it 'returns id when user has an active subscription' do
      user.add_subscription(subscription_type_id: Subscriptions::Type.stop_press.id, active: true)
      expect(user.stop_press_subscription).to be_a(String)
    end

    it 'returns false when user has an inactive subscription' do
      user.add_subscription(subscription_type_id: Subscriptions::Type.stop_press.id, active: false)
      expect(user.stop_press_subscription).to be false
    end

    it 'returns false when user does not have a subscription' do
      expect(user.stop_press_subscription).to be false
    end
  end

  describe '#my_commodities_subscription' do
    it 'returns id when user has an active subscription' do
      user.add_subscription(subscription_type_id: Subscriptions::Type.my_commodities.id, active: true)
      expect(user.my_commodities_subscription).to be_a(String)
    end

    it 'returns false when user has an inactive subscription' do
      user.add_subscription(subscription_type_id: Subscriptions::Type.my_commodities.id, active: false)
      expect(user.my_commodities_subscription).to be false
    end

    it 'returns false when user does not have a subscription' do
      expect(user.my_commodities_subscription).to be false
    end
  end

  describe '#stop_press_subscription=' do
    context 'when user has subscription' do
      before do
        user.add_subscription(subscription_type_id: Subscriptions::Type.stop_press.id, active: true)
      end

      context 'when value is true' do
        it 'enables the subscription' do
          user.stop_press_subscription = true
          expect(user.subscriptions.first.active).to be true
        end
      end

      context 'when value is false' do
        it 'disables the subscription' do
          user.stop_press_subscription = false
          expect(user.subscriptions.first.active).to be false
        end
      end
    end

    context 'when user has no subscription' do
      context 'when value is true' do
        it 'enables the subscription' do
          user.stop_press_subscription = true
          expect(user.subscriptions.first.active).to be true
        end

        it 'adds an action log for subscribed' do
          user.stop_press_subscription = true
          expect(user.action_logs.last.action).to eq PublicUsers::ActionLog::SUBSCRIBED_STOP_PRESS
        end
      end

      context 'when value is false' do
        it 'disables the subscription' do
          user.stop_press_subscription = false
          expect(user.subscriptions.first.active).to be false
        end
      end
    end
  end

  describe '#my_commdities_subscription=' do
    context 'when user has subscription' do
      before do
        user.add_subscription(subscription_type_id: Subscriptions::Type.my_commodities.id, active: true)
      end

      context 'when value is true' do
        it 'enables the subscription' do
          user.my_commodities_subscription = true
          expect(user.subscriptions.first.active).to be true
        end
      end

      context 'when value is false' do
        it 'disables the subscription' do
          user.my_commodities_subscription = false
          expect(user.subscriptions.first.active).to be false
        end
      end
    end

    context 'when user has no subscription' do
      context 'when value is true' do
        it 'enables the subscription' do
          user.my_commodities_subscription = true
          expect(user.subscriptions.first.active).to be true
        end

        it 'adds an action log for subscribed' do
          user.my_commodities_subscription = true
          expect(user.action_logs.last.action).to eq PublicUsers::ActionLog::SUBSCRIBED_MY_COMMODITIES
        end
      end

      context 'when value is false' do
        it 'disables the subscription' do
          user.my_commodities_subscription = false
          expect(user.subscriptions.first.active).to be false
        end
      end
    end
  end

  describe '#target_ids_for_my_commodities' do
    context 'when user has my commodities subscription' do
      before do
        subscription = user.add_subscription(subscription_type_id: Subscriptions::Type.my_commodities.id, active: true)
        create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: 1_234_567_890, target_type: 'commodity')
        create(:subscription_target, user_subscriptions_uuid: subscription.uuid, target_id: 987_654_321, target_type: 'commodity')
      end

      it 'returns array of target ids' do
        expect(user.target_ids_for_my_commodities).to contain_exactly(1_234_567_890, 987_654_321)
      end
    end

    context 'when user has no my commodities subscription' do
      it 'returns empty array' do
        expect(user.target_ids_for_my_commodities).to eq []
      end
    end
  end

  describe '#soft_delete!' do
    context 'when user has an active stop press subscription' do
      before do
        user.add_subscription(subscription_type_id: Subscriptions::Type.stop_press.id, active: true)
        user.soft_delete!
      end

      it 'user deleted should be false' do
        expect(user.deleted).to be false
      end
    end

    context 'when user has an inactive stop press subscription' do
      before do
        allow(ExternalUserDeletionWorker).to receive(:perform_async)
        user.add_subscription(subscription_type_id: Subscriptions::Type.stop_press.id, active: false)
        user.soft_delete!
      end

      it 'user deleted shoud be true' do
        expect(user.deleted).to be true
      end

      it 'creates an action log for deleted' do
        expect(user.action_logs.last.action).to eq PublicUsers::ActionLog::DELETED
      end

      it 'schedules deletion worker' do
        expect(ExternalUserDeletionWorker).to have_received(:perform_async)
      end
    end

    context 'when user has no subscription' do
      before do
        allow(ExternalUserDeletionWorker).to receive(:perform_async)
        user.soft_delete!
      end

      it 'user deleted shoud be true' do
        expect(user.deleted).to be true
      end

      it 'creates an action log for deleted' do
        expect(user.action_logs.last.action).to eq PublicUsers::ActionLog::DELETED
      end

      it 'schedules deletion worker' do
        expect(ExternalUserDeletionWorker).to have_received(:perform_async)
      end
    end
  end

  describe 'scopes' do
    describe '.with_active_stop_press_subscription' do
      subject(:dataset) { described_class.with_active_stop_press_subscription }

      let!(:user_with_active_subscription) { create(:public_user, :with_active_stop_press_subscription) }
      let!(:another_user_with_active_subscription) { create(:public_user, :with_active_stop_press_subscription) }
      let!(:user_with_inactive_subscription) { create(:public_user, :with_inactive_stop_press_subscription) }
      let!(:user_without_subscription) { create(:public_user) }
      let!(:user_with_different_active_subscription) { create(:public_user) }
      let!(:soft_deleted_user) { create(:public_user, :has_been_soft_deleted) }

      before do
        user_with_active_subscription
        another_user_with_active_subscription
        user_with_inactive_subscription
        user_without_subscription
        soft_deleted_user
        create(:user_subscription, user_id: user_with_different_active_subscription.id)
      end

      it 'returns expected users' do
        expect(dataset).to contain_exactly(user_with_active_subscription, another_user_with_active_subscription)
      end

      it 'excludes soft deleted users' do
        expect(dataset).not_to include(soft_deleted_user)
      end
    end

    describe '.matching_chapters' do
      subject(:dataset) { described_class.matching_chapters(chapters) }

      let(:user_with_chapter_1) { create(:public_user, :with_chapters_preference, chapters: '01') }
      let(:user_with_chapter_2_3) { create(:public_user, :with_chapters_preference, chapters: '02,03') }
      let(:user_with_chapter_3_4) { create(:public_user, :with_chapters_preference, chapters: '03,04') }
      let(:user_with_chapter_4) { create(:public_user, :with_chapters_preference, chapters: '04') }
      let(:user_with_chapter_1_2_3_4) { create(:public_user, :with_chapters_preference, chapters: '01,02,03,04') }
      let(:user_with_nil_preference) { create(:public_user, :with_chapters_preference, chapters: nil) }
      let(:user_with_empty_preference) { create(:public_user, :with_chapters_preference, chapters: '') }

      before do
        user_with_chapter_1
        user_with_chapter_2_3
        user_with_chapter_3_4
        user_with_chapter_4
        user_with_chapter_1_2_3_4
        user_with_nil_preference
        user_with_empty_preference
      end

      context 'when no chapters are specified' do
        let(:chapters) { '' }

        it 'returns all users' do
          expect(dataset).to contain_exactly(
            user_with_chapter_1,
            user_with_chapter_2_3,
            user_with_chapter_3_4,
            user_with_chapter_4,
            user_with_chapter_1_2_3_4,
            user_with_nil_preference,
            user_with_empty_preference,
          )
        end
      end

      context 'when no chapters are specified with nil' do
        let(:chapters) { nil }

        it 'returns all users' do
          expect(dataset).to contain_exactly(
            user_with_chapter_1,
            user_with_chapter_2_3,
            user_with_chapter_3_4,
            user_with_chapter_4,
            user_with_chapter_1_2_3_4,
            user_with_nil_preference,
            user_with_empty_preference,
          )
        end
      end

      context 'when 1 chapter is specified as array' do
        let(:chapters) { %w[01] }

        it 'returns expected users' do
          expect(dataset).to contain_exactly(user_with_chapter_1, user_with_chapter_1_2_3_4, user_with_nil_preference, user_with_empty_preference)
        end
      end

      context 'when 1 chapter is specified as string' do
        let(:chapters) { '01' }

        it 'returns expected users' do
          expect(dataset).to contain_exactly(user_with_chapter_1, user_with_chapter_1_2_3_4, user_with_nil_preference, user_with_empty_preference)
        end
      end

      context 'when multiple chapters are specified' do
        let(:chapters) { %w[01 02] }

        it 'returns expected users' do
          expect(dataset).to contain_exactly(user_with_chapter_1, user_with_chapter_2_3, user_with_chapter_1_2_3_4, user_with_nil_preference, user_with_empty_preference)
        end
      end
    end

    describe 'chain of scopes' do
      subject(:dataset) { described_class.active.with_active_stop_press_subscription.matching_chapters(chapters) }

      let(:chapters) { '01' }
      let(:active_user_with_subscription) { create(:public_user, :with_active_stop_press_subscription) }
      let(:inactive_user_with_subscription) { create(:public_user, :with_inactive_stop_press_subscription) }
      let(:active_user_without_subscription) { create(:public_user, deleted: false) }
      let(:deleted_user_with_subscription) { create(:public_user, :with_active_stop_press_subscription, deleted: true) }

      before do
        active_user_with_subscription
        inactive_user_with_subscription
        active_user_without_subscription
        deleted_user_with_subscription
      end

      it 'returns only active users with active stop press subscriptions' do
        expect(dataset).to contain_exactly(active_user_with_subscription)
      end
    end

    describe '.failed_subscribers' do
      let!(:old_user_no_sub) { create(:public_user, created_at: 4.days.ago, deleted: false) }
      let(:old_user_with_sub) { create(:public_user, :with_active_stop_press_subscription, created_at: 4.days.ago, deleted: false) }
      let(:recent_user_no_sub) { create(:public_user, created_at: 1.day.ago, deleted: false) }
      let(:recent_user_with_sub) { create(:public_user, :with_active_stop_press_subscription, created_at: 1.day.ago, deleted: false) }
      let(:deleted_user_no_sub) { create(:public_user, created_at: 4.days.ago, deleted: true) }

      it 'returns only users created more than 72 hours ago, not deleted, and without any subscription' do
        old_user_with_sub
        recent_user_no_sub
        recent_user_with_sub
        deleted_user_no_sub
        result = described_class.failed_subscribers.all
        expect(result).to contain_exactly(old_user_no_sub)
      end
    end
  end
end
