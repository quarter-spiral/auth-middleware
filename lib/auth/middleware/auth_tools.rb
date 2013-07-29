require 'json'
require 'cgi'
require 'uri'

module Auth
  class Middleware
    class AuthTools
      attr_accessor :token_owner
      attr_reader :request

      def initialize(middleware, env)
        @middleware = middleware
        @env = env
        @request = Rack::Request.new(env)
      end

      def cookie
        raw_cookie = @request.cookies()[@middleware.cookie_name]
        return nil unless raw_cookie
        @cookie ||= JSON.parse(raw_cookie)
      end

      def require_login!
        unless token_owner
          response = Rack::Response.new('', 302)
          p request.url
          uri = URI.parse(request.url)
          uri.path = '/auth/auth_backend'
          uri.query = nil
          uri.fragment = nil
          response.redirect(uri.to_s)
          throw(:response, response)
        end
      end

      def force_logout!
        redirect_url = "#{ENV['QS_AUTH_BACKEND_URL']}/signout?redirect_uri=#{CGI.escape(request.url)}"
        response = Rack::Response.new('', 301, 'Location' => redirect_uri)
        response.set_cookie(@cookie_name, :value => '', :path => "/", :expires => Time.new(1970).utc)
        response
      end
    end
  end
end