source 'https://rubygems.org'

# Specify your gem's dependencies in mygem.gemspec
gemspec

# TODO: add to gemspec
gem "bundler", ">= 1.11"
gem "rake", ">= 12.0"
gem "rdoc"
gem "logger" # no longer a default gem in Ruby 4.0+

# git: rather than github:, which Bundler 1.x (the default on Ruby 2.6) expands to an unsupported git:// URL.
gem "changelogd", git: "https://github.com/net-ssh/changelogd.git", tag: "v1", group: :development

gem 'byebug', group: %i[development test] if !Gem.win_platform? && RUBY_ENGINE == "ruby"

if ENV["CI"]
  gem 'codecov', require: false, group: :test
  gem 'simplecov', require: false, group: :test
end
