# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'spotty/version'

Gem::Specification.new do |spec|
  spec.name          = "spotty"
  spec.version       = Spotty::VERSION
  spec.authors       = ["Kyle King"]
  spec.email         = ["kylejking@gmail.com"]

  spec.summary       = 'A Spotify automation library for Ruby'
  spec.homepage      = "https://github.com/kylekyle/spotty"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "tty"
  spec.add_dependency "http"
  spec.add_dependency "multi_json"
  spec.add_dependency "addressable"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "bundler", "~> 1.12"
end
