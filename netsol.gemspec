lib = File.expand_path('../lib', __FILE__)

$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'netsol'
  spec.version       = '0.2.0'
  spec.authors       = ['Michael Malet']
  spec.email         = ['developers@tagadab.com']
  spec.description   = %q{A gem to make interacting with NetSol's Partner API less painful}
  spec.summary       = spec.description
  spec.homepage      = 'http://www.tagadab.com'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'nokogiri', '~> 1.6', '>= 1.6.8'
  spec.add_dependency 'haml'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'pry'
end