# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cocoapods-tj/gem_version.rb'

Gem::Specification.new do |spec|
  spec.name          = 'cocoapods-tj'
  spec.version       = CBin::VERSION
  spec.authors       = ['song']
  spec.email         = ['song@song.com']
  spec.description   = %q{}
  spec.summary       = %q{}
  spec.homepage      = 'https://github.com/songpanfei/cocoapods-tj'
  spec.license       = 'MIT'

  spec.files = Dir["lib/**/*.rb","spec/**/*.rb","lib/**/*.plist"] + %w{README.md LICENSE.txt }

  #spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'parallel'
  spec.add_dependency 'cocoapods'
  spec.add_dependency "cocoapods-generate"

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
end
