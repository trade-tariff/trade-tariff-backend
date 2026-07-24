RSpec.describe 'search analytics rake tasks' do
  describe 'search_analytics:validate_cloudwatch_queries' do
    subject(:task) { Rake::Task['search_analytics:validate_cloudwatch_queries'] }

    it 'runs without booting the Rails environment' do
      expect(task.prerequisites).not_to include('environment')
    end
  end
end
