RSpec.describe 'Admin hierarchy collection queries', type: :request do
  [['chapters', 1], ['sections', 3]].each do |resource, expected_count|
    it "keeps #{resource} queries constant as the collection grows" do
      create(:chapter, :with_section, :with_note)
      path = "/uk/admin/#{resource}.json"
      headers = request_headers(format: :json)
      get path, headers: headers

      counts = [0, 4].map do |additional|
        create_list(:chapter, additional, :with_section, :with_note)
        queries = []
        callback = lambda do |*args|
          queries << ActiveSupport::Notifications::Event.new(*args).payload[:sql].to_s
        end
        ActiveSupport::Notifications.subscribed(callback, /sql\.sequel/) { get path, headers: headers }

        expect(response).to have_http_status(:ok)
        queries.grep(/\ASELECT/i).length
      end

      expect(counts).to eq([expected_count, expected_count])
    end
  end
end
