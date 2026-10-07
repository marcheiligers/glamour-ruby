# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "ffi", "~> 1.17", platforms: :jruby

gem "irb"
gem "maxitest", "~> 7.0"
gem "rake", "~> 13.0"
gem "rubocop"

install_if -> { RUBY_ENGINE != "jruby" } do
  gem "rake-compiler", "~> 1.3"
  gem "rake-compiler-dock", "~> 1.11"
  gem "rbs-inline", "~> 0.12"
  gem "steep", "~> 1.10"
end
