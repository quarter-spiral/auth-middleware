# Auth::Middleware

Allow any app to be protected behind a login-wall using QS ID

## Usage

The middleware is a standard Rack middleware use it as such.

This makes the app only accesible when logged in:

```ruby
# config.ru

require 'auth/middleware'

authed_app = Rack::Builder.new do
  use Auth::Middleware, 'my-qs-app-id', 'my-qs-app-secret', 'qs_auth_cookie_name' do |auth_tools|
    auth_tools.require_login!
  end
  run MyOriginalApp
end

run authed_app
```

You can also allow only admins to access your app:

```ruby
# config.ru

require 'auth/middleware'

authed_app = Rack::Builder.new do
  use Auth::Middleware, 'my-qs-app-id', 'my-qs-app-secret', 'qs_auth_cookie_name' do |auth_tools|
    auth_tools.require_admin!
  end
  run MyOriginalApp
end

run authed_app
```