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
        redirect!('/auth/auth_backend', true) unless token_owner
      end

      def require_admin!
        require_login!

        render_message!("No access without admin privileges.") unless admin?
      end

      def force_logout!
        redirect_url = "#{ENV['QS_AUTH_BACKEND_URL']}/signout?redirect_uri=#{CGI.escape(request.url)}"
        response = Rack::Response.new('', 301, 'Location' => redirect_url)
        response.set_cookie(@cookie_name, :value => '', :path => "/", :expires => Time.new(1970).utc)
        response
      end

      def admin?
        token_owner && token_owner['admin'] == true
      end

      protected
      def redirect!(url, same_host = false)
        response = Rack::Response.new('', 302)
        if same_host
          uri = URI.parse(request.url)
          uri.path = url
          uri.query = nil
          uri.fragment = nil
          url = uri.to_s
        end
        response.redirect(url)
        throw(:response, response)
      end

      def render_message!(message)
        headers = {
            'Content-Type' => 'text/plain',
            'Content-Length' => message.bytesize
        }
        headers['Set-Cookie'] = @env['HTTP_COOKIE'] if @env['HTTP_COOKIE']
        Rack::Response.new(message, 200, headers)
      end
    end
  end
end