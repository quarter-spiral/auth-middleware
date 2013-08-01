require_relative './spec_helper'

require 'rack/client'
require 'uri'
require 'cgi'

describe Auth::Middleware do
  before do
    @harness = Qs::Test::Harness.harness
    @client = @harness.client
  end

  def handle_oauth_procedure(initial_response, user)
    cookie = user.logged_in_cookie

    app_cookie = initial_response.headers['Set-Cookie']

    response = @client.get initial_response.headers['Location'], headers: {'Referer' => "http://example.com/afterloginthing", 'Cookie' => app_cookie}
    response.status.must_equal 302
    response.headers['Location'].must_match /\/oauth\/authorize/
    app_cookie = response.headers['Set-Cookie']

    url = response.headers['Location']
    state = url.match(/(&|\?)state=(.*)(&.*)?$/).captures[1]
    state.wont_be_nil
    state.wont_be_empty

    auth_client = @harness.provider(:auth).client
    response = auth_client.get url, headers: {'Cookie' => cookie, 'Referer' => 'http://example.com/'}
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

    response = @client.get response.headers['Location'], headers: {'Cookie' => app_cookie}
    response.status.must_equal 301
    response.headers['Location'].must_equal "http://example.com/afterloginthing"
    app_cookie = response.headers['Set-Cookie']

    [app_cookie, @client.get(response.headers['Location'], headers: {'Cookie' => app_cookie})]
  end

  describe "login required" do
    before do
      MiddlewareInjector.reset!
      MiddlewareInjector.use Auth::Middleware, MIDDLEWARE_OAUTH_APP.id, MIDDLEWARE_OAUTH_APP.secret, 'qs_auth_middleware_test' do |auth_tools|
        auth_tools.require_login!
      end
    end

    it "shows you the secret page after login" do
      response = @client.get 'http://example.com/'
      response.status.must_equal 302
      response.body.must_be_empty

      user = @harness.entity_factory.create(:user)
      cookie, response = handle_oauth_procedure(response, user)

      response.status.must_equal 200
      response.body.must_equal "Secret - #{user.uuid}"
    end

    it "has a logout endpoint" do
      response = @client.get 'http://example.com/'
      user = @harness.entity_factory.create(:user)
      cookie, response = handle_oauth_procedure(response, user)
      response.status.must_equal 200
      response.body.must_equal "Secret - #{user.uuid}"

      response = @client.get 'http://example.com/', headers: {'Cookie' => cookie}
      response.status.must_equal 200
      response.body.must_equal "Secret - #{user.uuid}"

      response = @client.get 'http://example.com/auth/auth_backend/logout', headers: {'Cookie' => cookie}
      response.status.must_equal 302
      response.headers['Location'].must_equal "#{ENV['QS_AUTH_BACKEND_URL']}/signout?redirect_uri=#{CGI.escape('http://example.com/')}"

      cookie_expiration = response.headers['Set-Cookie'].match(/expires=(.*)(;.*)?$/i).captures.first
      date, time, junk = cookie_expiration.split(', ').last.split(' ')
      day, month, year = date.split('-')
      hour, minute, second = time.split(':')
      cookie_expiration = Time.new(year, month, day, hour.to_i, minute.to_i, second.to_i)

      cookie_expiration < Time.now
    end
  end

  describe "admin privileges required" do
    before do
      MiddlewareInjector.reset!
      MiddlewareInjector.use Auth::Middleware, MIDDLEWARE_OAUTH_APP.id, MIDDLEWARE_OAUTH_APP.secret, 'qs_auth_middleware_test' do |auth_tools|
        auth_tools.require_admin!
      end
    end

    it "redirects you back to login when logged in but not as an admin" do
      response = @client.get 'http://example.com/'
      response.status.must_equal 302
      response.body.must_be_empty

      user = @harness.entity_factory.create(:user, :admin => false)
      cookie, response = handle_oauth_procedure(response, user)

      response.status.must_equal 200
      response.body.must_equal "No access without admin privileges."

      response = @client.get 'http://example.com/', headers: {'Cookie' => cookie}
      response.status.must_equal 200
      response.body.must_equal "No access without admin privileges."
    end

    it "shows you the secret page when logged in as an admin" do
      response = @client.get 'http://example.com/'
      response.status.must_equal 302
      response.body.must_be_empty

      user = @harness.entity_factory.create(:user, :admin => true)
      cookie, response = handle_oauth_procedure(response, user)
      response.status.must_equal 200
      response.body.must_equal "Secret - #{user.uuid}"
    end
  end
end