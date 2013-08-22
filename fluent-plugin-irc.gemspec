# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "fluent-plugin-irc"
  s.version     = "0.0.5"
  s.authors     = ["OKUNO Akihiro"]
  s.email       = ["choplin.choplin@gmail.com"]
  s.homepage    = "https://github.com/choplin/fluent-plugin-irc"
  s.summary     = %q{Output plugin for IRC}
  s.description = %q{Output plugin for IRC}

  s.rubyforge_project = "fluent-plugin-irc"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency "fluentd"
  s.add_runtime_dependency "irc_parser"
end
