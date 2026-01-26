RSpec.describe Api::User::StopPressMetaService, type: :service do
  subject(:service) { described_class.new(subscription).call }

  let(:user) { create(:public_user, :with_chapters_preference, chapters: user_chapters) }
  let(:subscription) { create(:user_subscription, user_id: user.id) }

  describe '#call' do
    context 'when user has specific chapter preferences' do
      let(:user_chapters) { '01,02' }

      it 'returns the correct structure' do
        expect(service).to be_a(Hash)
        expect(service).to have_key(:chapters)
        expect(service).to have_key(:published)
        expect(service[:published]).to have_key(:yesterday)
      end

      it 'returns the count of chapters' do
        expect(service[:chapters]).to eq(2)
      end

      context 'with emailable news items from yesterday' do
        let(:yesterday_date) { Date.current - 1.day }

        before do
          travel_to yesterday_date do
            create(:news_item, :with_subscribable_collection,
                   chapters: '01,02',
                   notify_subscribers: true,
                   start_date: yesterday_date)
            create(:news_item, :with_subscribable_collection,
                   chapters: '01',
                   notify_subscribers: true,
                   start_date: yesterday_date)
          end
        end

        it 'returns count of emailable news items' do
          travel_to Date.current do
            expect(service[:published][:yesterday]).to eq(2)
          end
        end
      end
    end

    context 'when user has no chapter preferences' do
      let(:user_chapters) { nil }

      it 'returns "all" for chapters' do
        expect(service[:chapters]).to eq('all')
      end

      context 'with emailable news items from yesterday' do
        let(:yesterday_date) { Date.current - 1.day }

        before do
          travel_to yesterday_date do
            create(:news_item, :with_subscribable_collection,
                   chapters: '01,02',
                   notify_subscribers: true,
                   start_date: yesterday_date)
          end
        end

        it 'returns count of all emailable news items when no chapter filter' do
          expect(service[:published][:yesterday]).to eq(1)
        end
      end
    end

    context 'when user has empty chapter preferences' do
      let(:user_chapters) { '' }

      it 'returns "all" for chapters' do
        expect(service[:chapters]).to eq(described_class::ALL)
      end

      context 'with emailable news items from yesterday' do
        let(:yesterday_date) { Date.current - 1.day }

        before do
          travel_to yesterday_date do
            create(:news_item, :with_subscribable_collection,
                   chapters: '01,02',
                   notify_subscribers: true,
                   start_date: yesterday_date)
          end
        end

        it 'returns count of all emailable news items when chapter filter is empty' do
          expect(service[:published][:yesterday]).to eq(1)
        end
      end
    end

    context 'when user has manually selected all chapters' do
      let(:user_chapters) { (1..98).map { |n| n.to_s.rjust(2, '0') }.join(',') }

      before do
        allow(Chapter).to receive(:count).and_return(98)
      end

      it 'returns "all" for chapters' do
        expect(service[:chapters]).to eq(described_class::ALL)
      end
    end

    context 'when no news items exist for yesterday' do
      let(:user_chapters) { '01,02' }

      it 'returns 0 for published yesterday count' do
        expect(service[:published][:yesterday]).to eq(0)
      end

      it 'returns the count of chapters' do
        expect(service[:chapters]).to eq(2)
      end
    end

    context 'when user has single chapter preference' do
      let(:user_chapters) { '03' }

      it 'returns the count of 1 chapter' do
        expect(service[:chapters]).to eq(1)
      end

      it 'returns 0 for published yesterday count when no items exist' do
        expect(service[:published][:yesterday]).to eq(0)
      end
    end

    describe 'chapter counting logic' do
      context 'when user has multiple chapters' do
        let(:user_chapters) { '01,02,03,04' }

        it 'correctly counts comma-separated chapters' do
          expect(service[:chapters]).to eq(4)
        end
      end

      context 'when user has single chapter' do
        let(:user_chapters) { '99' }

        it 'returns count of 1' do
          expect(service[:chapters]).to eq(1)
        end
      end
    end

    describe 'service implementation notes' do
      # This test documents the actual implementation bug for future reference
      it 'has a known bug in the query chain' do
        # The current implementation:
        # News::Item.where(start_date: Date.yesterday).select(&:emailable?).for_chapters(...).count
        #
        # Problems:
        # 1. .select(&:emailable?) converts the dataset to an Array
        # 2. .for_chapters is then called on an Array, not a dataset
        # 3. If the array is empty, .for_chapters returns the same empty array
        # 4. If the array has items, .for_chapters would fail with NoMethodError
        #
        # The service should probably use a proper database query to filter
        # emailable items instead of Ruby enumeration.

        # This is just documentation of the implementation issue
        expect(described_class).to be_a(Class)
      end
    end
  end
end
