#!/usr/bin/env ruby
# frozen_string_literal: true

# Minitest suite validating the SDF Protocol Mapping CDDL definitions and every
# JSON example embedded in the Internet-Draft against that CDDL.
#
# It is a plain Minitest file (no test/ directory needed): run it directly with
#   ruby scripts/validate.rb        # compact dots
#   ruby scripts/validate.rb -v     # one named line per example (recommended)
#   ruby scripts/validate.rb -n test_properties_2_json   # a single example
# Set DRAFT_MD=/path to validate a different draft, SDF_CDDL_FILE=/path to use a
# local SDF grammar instead of fetching RFC 9880.
#
# What it checks:
#   * generated/combined.cddl is up to date with the cddl/*.cddl sources.
#   * A merged SDF model (RFC 9880 SDF formal syntax, fetched + cached under
#     .cddlcache/, + generated/combined.cddl) parses. The RFC version is used
#     because it declares the $$SDF-EXTENSION-* sockets this draft plugs into.
#   * Every embedded SDF JSON example validates as a real SDF document. Examples
#     using a registered protocol (ble/zigbee) validate against combined.cddl;
#     examples using an illustrative protocol defined only in the draft
#     (e.g. "new-protocol") validate against that draft-defined CDDL. Non-SDF
#     blocks (e.g. SCIM) are only checked for JSON well-formedness (skipped).
#
# Strictness note: RFC 9880's SDF grammar is intentionally open (the
# $$SDF-EXTENSION-* sockets are zero-or-more and it carries EXTENSION-POINT
# `.feature` wildcards). A malformed sdfProtocolMap therefore does not fail
# `cddl` outright -- it stops matching the typed socket and falls through to the
# wildcard, which `cddl` reports as a "Features potentially used" warning naming
# sdfProtocolMap. We treat that as a failure too.
#
# Requires: ruby (with Minitest, part of stdlib), the `cddl` gem, and the
# `kramdown-rfc` gem (provides `kramdown-rfc` and `kramdown-rfc-extract-sourcecode`).

require "minitest/autorun"
require "json"
require "yaml"
require "open3"
require "tempfile"
require "open-uri"
require "fileutils"

# Colored PASS / FAIL / SKIP line per test (no extra gems). Replaces the default
# progress dots. Set MINITEST_PLAIN=1 to keep Minitest's default reporters.
class PrettyReporter < Minitest::Reporter
  def record(result)
    tty = io.respond_to?(:tty?) && io.tty?
    paint = ->(code, s) { tty ? "\e[#{code}m#{s}\e[0m" : s }
    loc = "#{result.klass}##{result.name}"
    if result.skipped?
      why = result.failure.message.lines.first.to_s.strip
      io.puts "#{paint.call('33', 'SKIP')} #{loc}#{" — #{why}" unless why.empty?}"
    elsif result.passed?
      io.puts "#{paint.call('32', 'PASS')} #{loc}"
    else
      io.puts "#{paint.call('31', 'FAIL')} #{loc}"
    end
  end
end

unless ENV["MINITEST_PLAIN"]
  module Minitest
    def self.plugin_pretty_init(options)
      return unless reporter
      reporter.reporters.reject! { |r| r.is_a?(Minitest::ProgressReporter) }
      reporter << PrettyReporter.new(options[:io], options)
    end
  end
  (Minitest.extensions ||= []) << "pretty"
end

# Shared fixtures and helpers. Expensive work (draft extraction, RFC fetch,
# model building) is memoized so it runs once regardless of test order.
module Draft
  ROOT     = File.expand_path("..", __dir__)
  DRAFT_MD = ENV["DRAFT_MD"] || File.join(ROOT, "draft-ietf-asdf-sdf-protocol-mapping.md")
  MAKEFILE = File.join(ROOT, "Makefile")
  COMBINED = File.join(ROOT, "generated", "combined.cddl")

  # RFC 9880 SDF formal syntax: fetched and cached locally (offline after the
  # first run). Override with SDF_CDDL_FILE to use a local copy.
  SDF_RFC        = "9880"
  SDF_CDDL_URL   = "https://www.rfc-editor.org/rfc/rfc#{SDF_RFC}.xml"
  SDF_SOURCENAME = "cddl/formal-syntax-of-sdf.cddl"
  SDF_CACHE      = File.join(ROOT, ".cddlcache", "sdf-framework-rfc#{SDF_RFC}.cddl")

  # Top-level keys that mark a JSON block as an SDF document.
  SDF_KEYS = %w[sdfProperty sdfAction sdfEvent sdfObject sdfThing sdfData
                info namespace defaultNamespace].freeze

  module_function

  def run(*cmd, stdin_data: nil)
    Open3.capture3(*cmd, stdin_data: stdin_data)
  end

  # The `cddl` tool dumps the whole compiled schema AST on a validation failure.
  # Keep only the human-readable "validation failure (...)" lines, truncated.
  def concise_cddl_error(output)
    lines = output.lines.map(&:chomp).select { |l| l =~ /validation failure/i }
    lines = output.lines.first(3).map(&:chomp) if lines.empty?
    lines.map { |l| l.length > 300 ? "#{l[0, 300]} ..." : l }.join("\n")
  end

  def rel(path)
    path.start_with?("#{ROOT}/") ? path.sub("#{ROOT}/", "") : path
  end

  def tool?(name)
    system("command -v #{name} > /dev/null 2>&1")
  end

  # Protocols typed by a piece of CDDL: the property generic
  # `property-protocol-map<"x"...>` and the action/event socket entries
  # `$$SDF-*-PROTOCOL-MAP //= ( x: ... )` (bareword or quoted key).
  def typed_protocols(text)
    (text.scan(/property-protocol-map<\s*"([^"]+)"/).flatten +
     text.scan(/\$\$SDF-(?:ACTION|EVENT)-PROTOCOL-MAP\s*\/\/=\s*\(\s*"?([A-Za-z][\w-]*)"?\s*:/).flatten).uniq
  end

  # Collect the protocol names keyed under every "sdfProtocolMap" object.
  def protocols_used(node, acc = [])
    case node
    when Hash
      node.each do |k, v|
        acc.concat(v.keys) if k == "sdfProtocolMap" && v.is_a?(Hash)
        protocols_used(v, acc)
      end
    when Array
      node.each { |v| protocols_used(v, acc) }
    end
    acc.uniq
  end

  # `cddl` reports open-extension matches as e.g.
  #   ** Features potentially used (file): data-ext: ["sdfProtocolMap"]
  # sdfProtocolMap appearing there means it fell through to the open
  # EXTENSION-POINT wildcard instead of matching the typed protocol socket.
  def protocol_map_leaked?(output)
    output.lines.any? { |l| l =~ /Features potentially used/ && l.include?("sdfProtocolMap") }
  end

  # --- memoized fixtures ---------------------------------------------------

  def combined_cddl
    @combined_cddl ||= File.read(COMBINED)
  end

  def cddl_source_files
    text = File.read(MAKEFILE)
    lines = []
    capturing = false
    text.each_line do |l|
      capturing = true if l =~ /^CDDL_SOURCE_FILES\s*=/
      next unless capturing
      lines << l
      break unless l =~ /\\\s*$/
    end
    lines.join.scan(%r{[\w/\-]+\.cddl}).map { |f| File.join(ROOT, f) }
  end

  # Reproduce the Makefile recipe: cat each source file, then a newline.
  def regenerated_combined
    cddl_source_files.map { |f| File.read(f) + "\n" }.join
  end

  def blocks
    @blocks ||= begin
      out, err, st = run("kramdown-rfc", DRAFT_MD)
      abort "kramdown-rfc failed to build XML:\n#{err}" unless st.success?
      Tempfile.create(["draft", ".xml"]) do |xml|
        xml.write(out)
        xml.flush
        yout, yerr, yst = run("kramdown-rfc-extract-sourcecode", "-t", "yaml", xml.path)
        abort "kramdown-rfc-extract-sourcecode failed:\n#{yerr}" unless yst.success?
        YAML.safe_load(yout) || {}
      end
    end
  end

  def json_blocks = blocks["json"] || {}
  def cddl_blocks = blocks["cddl"] || {}

  def sdf_cddl
    @sdf_cddl ||= load_sdf_cddl.first
  end

  # [cddl_text, source_desc]; SDF_CDDL_FILE override -> cache -> fetch + cache.
  def load_sdf_cddl
    if (override = ENV["SDF_CDDL_FILE"])
      abort "SDF_CDDL_FILE set but not found: #{override}" unless File.file?(override)
      return [File.read(override), "SDF_CDDL_FILE=#{override}"]
    end
    return [File.read(SDF_CACHE), "cache #{rel(SDF_CACHE)}"] if File.file?(SDF_CACHE) && !File.zero?(SDF_CACHE)

    cddl = fetch_sdf_cddl
    FileUtils.mkdir_p(File.dirname(SDF_CACHE))
    File.write(SDF_CACHE, cddl)
    [cddl, "RFC #{SDF_RFC} (fetched, cached to #{rel(SDF_CACHE)})"]
  end

  def fetch_sdf_cddl
    xml = URI.open(SDF_CDDL_URL, open_timeout: 20, read_timeout: 60, &:read)
    Tempfile.create(["rfc#{SDF_RFC}", ".xml"]) do |xmlf|
      xmlf.write(xml)
      xmlf.flush
      out, err, st = run("kramdown-rfc-extract-sourcecode", "-x", SDF_SOURCENAME, xmlf.path)
      abort "Could not extract '#{SDF_SOURCENAME}' from RFC #{SDF_RFC} XML:\n#{err}" unless st.success? && !out.strip.empty?
      out
    end
  rescue OpenURI::HTTPError, SocketError, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout => e
    abort "Failed to fetch SDF CDDL from #{SDF_CDDL_URL}: #{e.message}\n" \
          "Provide a local copy via SDF_CDDL_FILE=/path/to/sdf.cddl to run offline."
  end

  # Illustrative example-extension CDDL from the draft: any extracted CDDL block
  # not already part of combined.cddl (e.g. the "new-protocol" definitions).
  def example_ext_cddl
    @example_ext_cddl ||= begin
      combined_norm = combined_cddl.gsub(/\s+/, "")
      cddl_blocks.reject { |_n, b| combined_norm.include?(b.gsub(/\s+/, "")) }
                 .map { |n, b| "; from #{n}\n#{b}" }.join("\n\n")
    end
  end

  def build_model(extra = nil)
    m = Tempfile.new(["sdf-model", ".cddl"])
    m.write("; ==== RFC #{SDF_RFC} SDF formal syntax ====\n#{sdf_cddl}\n")
    m.write("; ==== generated/combined.cddl (this draft's protocol maps) ====\n#{combined_cddl}\n")
    m.write("; ==== illustrative example extensions from the draft ====\n#{extra}\n") if extra && !extra.empty?
    m.flush
    m
  end

  # Base model types the registered protocols (ble/zigbee); the extended model
  # additionally types the draft's illustrative protocols (new-protocol).
  def base_model = @base_model ||= build_model
  def ext_model  = @ext_model  ||= (example_ext_cddl.empty? ? nil : build_model(example_ext_cddl))

  def known_protocols = @known_protocols ||= typed_protocols(combined_cddl)
  def ext_protocols
    @ext_protocols ||= ext_model ? typed_protocols("#{combined_cddl}\n#{example_ext_cddl}") : known_protocols
  end
end

# --- environment prerequisites (fail fast, before any test runs) ------------
%w[cddl kramdown-rfc kramdown-rfc-extract-sourcecode].each do |t|
  abort "Missing required tool '#{t}'. Install the cddl and kramdown-rfc gems." unless Draft.tool?(t)
end
abort "Draft not found: #{Draft::DRAFT_MD}" unless File.file?(Draft::DRAFT_MD)
abort "Combined CDDL not found: #{Draft::COMBINED} (run `make #{File.basename(Draft::COMBINED)}`)" unless File.file?(Draft::COMBINED)

Minitest.after_run { [Draft.base_model, Draft.ext_model].compact.each { |m| m.close; m.unlink } }

# ---------------------------------------------------------------------------
class CddlModelTest < Minitest::Test
  def test_combined_cddl_is_up_to_date
    assert_equal Draft.regenerated_combined, Draft.combined_cddl,
                 "generated/combined.cddl is stale; run `make generated/combined.cddl`"
  end

  def test_base_model_parses
    _o, err, st = Draft.run("cddl", Draft.base_model.path, "generate", "1")
    assert st.success?, "base SDF model (RFC #{Draft::SDF_RFC} + combined.cddl) does not parse:\n#{Draft.concise_cddl_error(err)}"
    refute_empty Draft.known_protocols, "no registered protocols detected in combined.cddl"
  end

  def test_example_extension_model_parses
    skip "no illustrative example extensions in the draft" unless Draft.ext_model
    _o, err, st = Draft.run("cddl", Draft.ext_model.path, "generate", "1")
    assert st.success?, "draft example-extension CDDL does not parse:\n#{Draft.concise_cddl_error(err)}"
  end
end

# ---------------------------------------------------------------------------
# One test per JSON example embedded in the draft.
class SdfJsonExampleTest < Minitest::Test
  Draft.json_blocks.each do |name, body|
    define_method("test_#{name.gsub(/[^0-9A-Za-z]+/, '_')}") do
      begin
        parsed = JSON.parse(body)
      rescue JSON::ParserError => e
        flunk "#{name}: not well-formed JSON: #{e.message}"
      end

      unless parsed.is_a?(Hash) && (Draft::SDF_KEYS & parsed.keys).any?
        skip "#{name}: not an SDF document (no CDDL model in this draft)"
      end

      # Pick the smallest model that types the protocols this example uses.
      protos = Draft.protocols_used(parsed)
      if (protos - Draft.known_protocols).empty?
        model, via = Draft.base_model, "combined.cddl"
      elsif Draft.ext_model && (protos - Draft.ext_protocols).empty?
        model, via = Draft.ext_model, "draft example CDDL"
      else
        skip "#{name}: uses protocol(s) with no CDDL definition (#{(protos - Draft.ext_protocols).join(', ')})"
      end

      Tempfile.create(["example", ".json"]) do |tmp|
        tmp.write(body)
        tmp.flush
        out, err, st = Draft.run("cddl", model.path, "validate", tmp.path)
        combined_out = [out, err].join
        assert st.success?,
               "#{name} [via #{via}] failed SDF validation:\n#{Draft.concise_cddl_error(combined_out)}"
        refute Draft.protocol_map_leaked?(combined_out),
               "#{name} [via #{via}] has a malformed sdfProtocolMap (did not match its protocol's typed mapping):\n" +
               combined_out.lines.grep(/Features potentially used/).join.strip
      end
    end
  end
end
