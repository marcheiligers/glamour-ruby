# frozen_string_literal: true

require "ffi"
require "rbconfig"

module Glamour
  module Native
    extend FFI::Library

    class << self
      def library_path
        return ENV.fetch("GLAMOUR_LIBRARY_PATH") if ENV.key?("GLAMOUR_LIBRARY_PATH")

        extension = host_os == "darwin" ? "dylib" : "so"
        File.expand_path("../../go/build/#{host_os}_#{host_arch}/libglamour.#{extension}", __dir__)
      end

      private

      def host_arch
        case RbConfig::CONFIG["host_cpu"]
        when /aarch64|arm64/ then "arm64"
        when /x86_64|amd64/ then "amd64"
        else RbConfig::CONFIG["host_cpu"]
        end
      end

      def host_os
        case RbConfig::CONFIG["host_os"]
        when /darwin/ then "darwin"
        when /linux/ then "linux"
        else
          raise LoadError, "glamour does not support JRuby on #{RbConfig::CONFIG["host_os"]}"
        end
      end
    end

    ffi_lib library_path

    attach_function :glamour_render, %i[string string], :pointer
    attach_function :glamour_render_with_options,
                    %i[string string int int int string int],
                    :pointer
    attach_function :glamour_render_with_json_style, %i[string string int], :pointer
    attach_function :glamour_free, [:pointer], :void
    attach_function :glamour_upstream_version, [], :pointer
  end

  COLOR_PROFILES = {
    true_color: 1,
    ansi256: 2,
    ansi: 3,
    ascii: 4
  }.freeze

  class << self
    def render(markdown, style: "auto", width: 0, emoji: false, preserve_newlines: false, base_url: nil,
               color_profile: nil, **)
      markdown = native_string(markdown)
      style = "auto" if style.nil?
      style = native_string(style)
      width = width.nil? ? 0 : native_integer(width)
      base_url = native_string(base_url) unless base_url.nil?

      pointer = render_pointer(markdown, style, width, emoji, preserve_newlines, base_url, color_profile)
      string_from_native(pointer)
    end

    def render_with_json(markdown, json_style, width: 0, **)
      width = 0 if width.nil?
      pointer = Native.glamour_render_with_json_style(
        native_string(markdown),
        native_string(json_style),
        native_integer(width)
      )
      string_from_native(pointer)
    end

    def upstream_version
      string_from_native(Native.glamour_upstream_version)
    end

    def version
      format(
        "glamour v%<version>s (upstream %<upstream>s) [Go native extension]",
        version: VERSION,
        upstream: upstream_version
      )
    end

    private

    def render_pointer(markdown, style, width, emoji, preserve_newlines, base_url, color_profile)
      advanced = emoji || preserve_newlines || !base_url.nil? || !color_profile.nil?
      return Native.glamour_render(markdown, style) unless advanced || width.positive?

      Native.glamour_render_with_options(
        markdown,
        style,
        width,
        emoji ? 1 : 0,
        preserve_newlines ? 1 : 0,
        base_url,
        COLOR_PROFILES.fetch(color_profile, 0)
      )
    end

    def native_string(value)
      raise TypeError, "wrong argument type #{value.class} (expected String)" unless value.is_a?(String)
      raise ArgumentError, "string contains null byte" if value.include?("\0")

      value
    end

    def native_integer(value)
      return value if value.is_a?(Integer) && value.between?(-2_147_483_648, 2_147_483_647)
      raise RangeError, "integer out of range" if value.is_a?(Integer)

      converted = value.to_int
      return converted if converted.between?(-2_147_483_648, 2_147_483_647)

      raise RangeError, "integer out of range"
    rescue NoMethodError
      raise TypeError, "no implicit conversion of #{value.class} into Integer"
    end

    def string_from_native(pointer)
      return "" if pointer.null?

      pointer.read_string.force_encoding(Encoding::UTF_8)
    ensure
      Native.glamour_free(pointer) if pointer && !pointer.null?
    end
  end

  class Renderer
    attr_accessor :style, :width, :emoji, :preserve_newlines, :base_url, :color_profile, :json_style

    def initialize(style: "auto", width: 0, emoji: false, preserve_newlines: false, base_url: nil,
                   color_profile: :auto, json_style: nil, **)
      @style = style.nil? ? "auto" : style
      @width = width.nil? ? 0 : width
      @emoji = emoji ? true : false
      @preserve_newlines = preserve_newlines ? true : false
      @base_url = base_url
      @color_profile = color_profile.nil? ? :auto : color_profile
      @json_style = json_style
    end

    def render(markdown)
      width = Glamour.__send__(:native_integer, @width)

      if @json_style
        Glamour.render_with_json(markdown, Glamour.__send__(:native_string, @json_style), width: width)
      else
        Glamour.render(
          markdown,
          style: @style,
          width: width,
          emoji: @emoji,
          preserve_newlines: @preserve_newlines,
          base_url: @base_url,
          color_profile: @color_profile
        )
      end
    end
  end
end
