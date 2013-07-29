ENV['RACK_ENV'] ||= 'test'
ENV['QS_AUTH_BACKEND_URL'] = 'http://auth-backend.dev'

Bundler.require

require 'minitest/autorun'

require 'auth/middleware'

class MiddlewareInjector
  def initialize(app)
    @app = app
  end

  def self.use(middleware, *args, &blck)
    @middleware = middleware
    @middleware_args = args
    @middleware_blck = blck
  end

  def self.middleware
    @middleware
  end

  def self.middleware_args
    @middleware_args
  end

  def self.middleware_blck
    @middleware_blck
  end

  def call(env)
    setup! unless setup?
    @middleware.call(env)
  end

  protected
  def setup!
    raise "No middleware set. Can't use the MiddlewareInjector" unless self.class.middleware

    if self.class.middleware_blck
      @middleware = self.class.middleware.new(@app, *(self.class.middleware_args || []), &self.class.middleware_blck)
    else
      @middleware = self.class.middleware.new(@app, *(self.class.middleware_args || []))
    end
  end

  def setup?
    !!@middleware
  end
end

class SampleApp
  def self.new
    Rack::Builder.new do
      use Rack::Session::Cookie, key: 'qs_auth_middleware_test', secret: '1234567890'
      use MiddlewareInjector

      run lambda {|e| [200, {'Content-Type' => 'text/plain'}, ["Secret - #{e['qs_token_owner']}"]]}
    end
  end
end

Qs::Test::Harness.setup! do
  provide Qs::Test::Harness::Provider::Datastore
  provide Qs::Test::Harness::Provider::Graph
  provide Qs::Test::Harness::Provider::Auth

  test SampleApp
end

oauth_app = Qs::Test::Harness.harness.entity_factory.create(:app, redirect_url: "http://example.com/auth/auth_backend/callback")

MIDDLEWARE_OAUTH_APP = oauth_app
MiddlewareInjector.use Auth::Middleware, oauth_app.id, oauth_app.secret, 'qs_auth_middleware_test' do |auth_tools|
  auth_tools.require_login!
end