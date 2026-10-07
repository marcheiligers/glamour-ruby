# frozen_string_literal: true

require_relative "test_helper"

if RUBY_ENGINE == "jruby"
  module Glamour
    class JRubyBackendTest < Minitest::Test
      def test_loads_shared_library_backend
        assert File.file?(Glamour::Native.library_path)
        assert_match(/upstream v\d+\.\d+\.\d+/, Glamour.version)
      end

      def test_preserves_native_argument_checks
        assert_raises(TypeError) { Glamour.render(nil) }
        assert_raises(TypeError) { Glamour.render("text", width: "20") }
        assert_raises(ArgumentError) { Glamour.render("bad\0markdown") }
      end

      def test_renderer_attributes_remain_mutable
        renderer = Glamour::Renderer.new(color_profile: :ascii)
        renderer.width = 40

        assert_equal 40, renderer.width
        assert_includes renderer.render("# Hello"), "Hello"
      end
    end
  end
end
