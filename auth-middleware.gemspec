# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'auth/middleware/version'

Gem::Specification.new do |spec|
  spec.name          = "auth-middleware"
  spec.version       = Auth::Middleware::VERSION
  spec.authors       = ["Thorben Schröder"]
  spec.email         = ["stillepost@gmail.com"]
  spec.description   = %q{Allow any app to be protected behind a login-wall using QS ID}
  spec.summary       = %q{Allow any app to be protected behind a login-wall using QS ID}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rack-client"
  spec.add_development_dependency 'qs-test-harness', '>= 0.0.1'

  spec.add_dependency 'rack', '>= 1.4.5'
  spec.add_dependency 'omniauth'
  spec.add_dependency 'omniauth-oauth2'
  spec.add_dependency 'json'

  spec.add_dependency 'auth-client', '>= 0.0.16'
end
