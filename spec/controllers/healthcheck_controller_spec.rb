describe HealthcheckController, 'GET #index' do
  it 'tries to fetch section index' do
    expect(Section).to receive(:all).and_return(true)

    get :index
  end

  it 'returns current release sha' do
    get :index

    expect(response.body).to match_json_expression(git_sha1: String)
  end
end
