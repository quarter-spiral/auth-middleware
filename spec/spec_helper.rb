ENV['RACK_ENV'] ||= 'test'
ENV['QS_AUTH_BACKEND_URL'] = 'http://auth-backend.dev'

Bundler.require

require 'minitest/autorun'

require 'auth/middleware'

class MiddlewareInjector
  def initialize(app)
    @app = app
    self.class.instances << self
  end

  def self.instances
    @instances ||= []
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

  def self.reset!
    instances.each(&:reset!)
  end

  def reset!
    @middleware = nil
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

class AuthClientAugmenter
  def <<(client)
    @clients ||= []
    @clients << client
    process!
  end

  def app=(app)
    @app = app
    process!
  end

  def process!
    return unless @app
    while client = @clients.shift
      client.instance_variable_set('@adapter', Service::Client::Adapter::Faraday.new(adapter: [:rack, @app]))
    end
  end
end

QS_AUTH_CLIENT_AUGMENTER = AuthClientAugmenter.new

require 'auth-client'
module Auth
  class Client
    alias raw_initialize initialize
    def initialize(*args)
      raw_initialize(*args)
      QS_AUTH_CLIENT_AUGMENTER << self
    end
  end
end

class SampleApp
  def self.new
    Rack::Builder.new do
      use Rack::Session::Cookie, key: 'qs_auth_middleware_test', secret: '1234567890'
      use MiddlewareInjector

      run lambda {|e| [200, {'Content-Type' => 'text/plain'}, ["Secret - #{e['qs_auth_tools'].token_owner['uuid']}"]]}
    end
  end
end

class OauthInjectorApp
  def self.app=(app)
    @app = app
  end

  def self.app
    @app
  end

  def self.call(env)
    request = Rack::Request.new(env)

    app.call(env)
  end
end

require 'oauth2'
module OAuth2
  class Client
    # The Faraday connection object
    def connection
      @__connection ||= begin
        conn = Faraday.new(site, options[:connection_opts])
        conn.build do |b|
          options[:connection_build].call(b) if options[:connection_build]
        end
        conn.request :url_encoded
        conn.adapter :rack, OauthInjectorApp
        conn
      end
    end
  end
end

Qs::Test::Harness.setup! do
  provide Qs::Test::Harness::Provider::Datastore
  provide Qs::Test::Harness::Provider::Graph
  provide Qs::Test::Harness::Provider::Auth

  test SampleApp
end

OauthInjectorApp.app = Qs::Test::Harness.harness.provider(:auth).app

QS_AUTH_CLIENT_AUGMENTER.app = Qs::Test::Harness.harness.provider(:auth).app

oauth_app = Qs::Test::Harness.harness.entity_factory.create(:app, redirect_url: "http://example.com/auth/auth_backend/callback")

MIDDLEWARE_OAUTH_APP = oauth_app