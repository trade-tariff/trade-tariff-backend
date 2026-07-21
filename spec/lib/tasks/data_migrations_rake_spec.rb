require 'open3'

RSpec.describe 'Data migration Rake tasks' do
  describe 'data:migrate:load' do
    it 'documents its environment-loading purpose' do
      output, status = Open3.capture2e(
        Rails.root.join('bin/rake').to_s,
        '-T',
        'data:migrate:load',
      )

      expect(status).to be_success
      expect(output).to include('rake data:migrate:load  # Load the data migration environment')
    end
  end
end
