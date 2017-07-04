# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "fluent-plugin-irc"
  s.version     = "0.0.8"
  s.authors     = ["OKUNO Akihiro"]
  s.email       = ["choplin.choplin@gmail.com"]
  s.homepage    = "https://github.com/fluent-plugins-nursery/fluent-plugin-irc"
  s.summary     = %q{Output plugin for IRC}
  s.description = %q{Output plugin for IRC}
  s.license     = "Apache-2.0"

  s.rubyforge_project = "fluent-plugin-irc"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency "fluentd", [">= 0.14.0", "< 2"]
  s.add_runtime_dependency "irc_parser"

  s.add_development_dependency "test-unit"
  s.add_development_dependency "rake"
end
