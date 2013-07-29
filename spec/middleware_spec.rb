require_relative './spec_helper'

require 'rack/client'
require 'uri'

describe Auth::Middleware do
  before do
    @harness = Qs::Test::Harness.harness
    @client = @harness.client
  end

  it "redirects to login when not logged in" do
    user = @harness.entity_factory.create(:user)
    cookie = user.logged_in_cookie

    response = @client.get 'http://example.com/'
    response.status.must_equal 302
    response.body.must_be_empty

    response = @client.get response.headers['Location']
    response.status.must_equal 302
    response.headers['Location'].must_match /\/oauth\/authorize/

    url = response.headers['Location']
    state = url.match(/(&|\?)state=(.*)(&.*)?$/).captures[1]
    state.wont_be_nil
    state.wont_be_empty

    auth_client = @harness.provider(:auth).client
    response = auth_client.get url, headers: {'Cookie' => cookie}
    response.status.must_equal 200
    response.body.index('"/oauth/allow"').wont_be_nil
    response.body.index(state).wont_be_nil
    cookie = response.headers['Set-Cookie']


    params = {
      response_type: 'code',
      client_id: MIDDLEWARE_OAUTH_APP.id,
      redirect_uri: MIDDLEWARE_OAUTH_APP.redirect_url,
      state: state,
      allow: '1'
    }
    body = URI.encode_www_form(params)
    response = auth_client.post "/oauth/allow", headers: {'Cookie' => cookie}, body: body
    response.status.must_equal 302
    response.headers['Location'].index('http://example.com/auth/auth_backend/callback').wont_be_nil
    response.headers['Location'].must_match /(&|\?)code=[^&]+(&.*)?$/
  end
end