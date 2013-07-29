require "auth/middleware/version"
require "auth/middleware/auth_tools"
require "auth/middleware/qs_strategy"

require 'auth-client'

module Auth
  class Middleware
    attr_reader :options, :cookie_name

    def initialize(app, app_id, app_secret, cookie_name, &blck)
      @omniauth_strategy = QsStrategy.new(app, app_id, app_secret)
      @cookie_name = cookie_name
      @options = options

      @auth_client = Auth::Client.new(ENV['QS_AUTH_BACKEND_URL'])

      @auth_block = blck
    end

    def call(env)
      if request_should_be_handled?(env)
        auth_tools = env['qs_auth_tools'] = AuthTools.new(self, env)

        if auth_cookie = auth_tools.cookie
          return auth_tools.force_logout! unless auth_tools.token_owner = @auth_client.token_owner(auth_cookie['info']['token'])
        end

        if @auth_block
          response = catch(:response) do
            @auth_block.call(auth_tools)
          end
          return response if response
        end
      end

      result = @omniauth_strategy.call(env)

      if env['PATH_INFO'] == "/auth/auth_backend/callback"
        response = Rack::Response.new('', 301, 'Location' => env['omniauth.origin'])
        response.set_cookie(@cookie_name, value: JSON.dump(env['omniauth.auth']), path: '/')
        response
      else
        result
      end
    end

    protected
    def request_should_be_handled?(env)
      !env['PATH_INFO'].match(/^\/auth\/auth_backend/)
    end
  end
end
