# encoding: UTF-8
require_relative 'lib/spree_payu/version.rb'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_payu'
  s.version     = SpreePayuGateway.version
  s.summary     = 'PayU India payment gateway for Spree 5.1'
  s.description = 'PayU India payment gateway for Spree 5.1'
  s.required_ruby_version = '>= 3.0'
  s.license     = 'BSD-3-Clause'

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/umeshravani/spree_payu/issues",
    "changelog_uri"     => "https://github.com/umeshravani/spree_payu/releases/tag/#{s.version}",
    "source_code_uri"   => "https://github.com/umeshravani/spree_payu/tree/#{s.version}",
  }

  s.authors           = ['Umesh Ravani']
  s.email             = 'umeshravani98@gmail.com'
  s.homepage          = 'https://github.com/umeshravani/spree_payu'

  s.files        = Dir['CHANGELOG', 'README.md', 'LICENSE', 'lib/**/*', 'app/**/*']
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency('deface')
  s.add_dependency('faraday')
  s.add_dependency('openssl')

  spree_version =  '~> 5.1.1'
  s.add_dependency 'spree_admin', spree_version
  s.add_dependency 'spree_core', spree_version
  s.add_dependency 'spree_auth_devise'
  s.add_dependency 'countries'
  s.add_dependency  'bigdecimal'
end
