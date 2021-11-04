RSpec.shared_context 'with meursing additional code id' do |meursing_additional_code_id|
  around do |example|
    Thread.current[:meursing_additional_code_id] = meursing_additional_code_id
    example.run
    Thread.current[:meursing_additional_code_id] = nil
  end
end
