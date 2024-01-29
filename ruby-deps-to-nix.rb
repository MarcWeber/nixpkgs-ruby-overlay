# encoding: UTF-8
#
# tested with ruby 2.0 to 2.4
#
# ruby ruby-deps-to-nix.rb --cache-file /tmp/cache --json-deps '{...}'

require 'rubygems'
require 'rubygems/remote_fetcher'
require 'rubygems/resolver'
require 'rubygems/available_set'
require 'rubygems/request_set'
require 'json'
# require 'rubygems/sourcd'
require 'rubygems/source/local'

$PATCHES = {
  'ruby-debug-ide' => ['debase'],
  'nokogiri'       => ['mini_portile2'],
  'sup'            => ['xapian-ruby'],
  'xapian-ruby'    => ['rake'],
  'solargraph'     => ['rubocop', 'rest-client'],
}

def patch(v)
  to_patch = $PATCHES.keys & ( v[:deps].map {|v| (v.is_a? String) ? v : [0]})
  to_patch.each do |p|
    v[:deps] += $PATCHES[p].map {|v| [v] }
    v[:deps_patches] ||= {}
    v[:deps_patches][p] ||= []
    v[:deps_patches][p] += $PATCHES[p]
    v[:deps_patches][p].uniq!
  end
  v[:deps].uniq!
end

def lines_by_deps(cache_obj, o)
  deps = o.fetch(:deps)
  deps_patches = o.fetch(:deps_patches, {})

  set = Gem::RequestSet.new *(deps.map {|v| Gem::Dependency.new(*v)})
  requests = set.resolve


  lines = []
  cache_obj.with do |cache|
    lines << "# #{deps.inspect}"
    lines << "{build_ruby_package, fix, fetchurl}: fix (rpkgs: {"
    requests.each do |request|
      h = {}
      h[:src] = NixV.new "fetchurl #{src_from_request(request, cache_obj).to_nix}"
      h[:name] = request.name
      h[:version] = request.version
      h[:dependencies] = request.spec.dependencies.map(&:name) + deps_patches.fetch(request.name, [])
      # not using request.full_name because dependency list does not contain full_name
      lines << "#{request.name.to_nix} = build_ruby_package rpkgs #{h.to_nix};"
    end
    lines << "})"
  end

  lines
end

def run(cache_obj, v, output_style)
  pkg_lines = lines_by_deps(cache_obj, v)
  lines = []
  case output_style
  when :plain
    lines << (arg.to_s + ("=" * 20))
  when :env
    lines << "
      ( rubyEnv {
        name = \"#{v.fetch(:name)}\";
        ruby = pkgs.#{$RUBY_VERSION};

        pkgs_fun =
        #{pkg_lines.join("\n")};
      })
    "
  end
  lines
end

## LIB
class Array
  def to_nix; "[" + self.map(&:to_nix).join(" ") + "]"; end
end

class String
  def to_nix; "\"#{self}\""; end
end

class Hash
  def self.key_value(k, v)
    "#{k.to_nix} = #{v.to_nix};".to_sym
  end
  def to_nix
    "{#{self.keys.map {|k| Hash.key_value(k, self[k])  }.join(" ")}}";
  end
end

class NixV
  def initialize(v)
    @v = v
  end
  def to_nix
    @v
  end
end

class Object; def to_nix; self.to_s.to_nix; end; end

class FileCached
  def initialize(config)
    @config = {
      :default => {},
      :from_file => lambda{|filename| File.open(filename, "rb") { |file| Marshal.load(file) } },
      :to_binary => lambda{|t| Marshal.dump(t) },
      :use_cache => true,
      :load_cache => config[:use_cache] || config[:load_cache],
      :write_cache => config[:use_cache] || config[:write_cache],
    }.merge(config)
  end

  def load_cache
    return if @cache
    if @config[:load_cache] and (File.exist? @config[:filename])
      @cache = @config[:from_file].call(@config[:filename])
      @read  = @config[:to_binary].call(@cache)
    else
      @cache = @config[:default]
      @read = nil
    end
  end

  def dump_cache
    return unless @config[:write_cache]
    # check whether it was changed
    binary = @config[:to_binary].call(@cache)
    File.open(@config[:filename],"w") {|f| f.write binary } if binary != @read
  end

  def with(opts = {})
    load_cache
    begin
      r = yield @cache
    ensure
      dump_cache unless opts[:only_reading] or opts[:write_cache]
    end
    r
  end

  def get(*keys, &blk)
    h = @cache
    while keys.count > 1
      k = keys.shift
      @cache[k] ||= {}
      h = @cache[k]
    end
    k = keys.shift
    if not h.include? k
      h[k] = yield
    end
    h[k]
  end

end

## LIB END

def src_from_request(r, cache_obj)
  src = {}
  # r.name was r.full_name but caused errors
  src[:url] = "http://production.cf.rubygems.org/gems/#{r.name}-#{r.version}.gem"
  src.merge! (cache_obj.get("src_hash", src[:url]) do
    # returns {md5 => or sha256 => }
    h = {}
    # TODO rewrite using ruby code?

    # gem_file = Gem::RemoteFetcher.fetcher.download r, src[:url], '/tmp/'
    h[:sha256] = `nix-prefetch-url #{src[:url]} 2>&1 | tail -n 1`.strip
    raise "bad hash from nix-prefetch-url from #{src[:url]} #{h[:sha256]}" unless h[:sha256].length == "1p3f43scdzx9zxmy2kw5zsc3az6v46nq4brwcxmnscjy4w4racbv".length

    h
  end)
  src
end

$CACHE_FILE_OR_NIL = ENV['HOME']+"/.nix2ruby-resolve-deps"

$RUBY_VERSION = "ruby_2_7";

cache_obj = FileCached.new(:filename => nil, :use_cache => false)

i = 0
while i < ARGV.length
  arg = lambda do
    i+=1
    ARGV[i-1]
  end
  v = arg.call
  case v
  when '--ruby-version'
    $RUBY_VERSION = arg.call
  when '--cache-file'
    cache_obj = FileCached.new(:filename => arg.call, :use_cache => true)
  when '--json-deps-arg'
    deps = JSON.parse(arg.call)
    patch(deps)
    puts run(cache_obj, deps, :env).join("\n")
  when '--json-deps-file'
    deps = JSON.parse(File.open(arg.call).read, {:symbolize_names => true})
    patch(deps)
    puts '#'+deps.inspect
    puts run(cache_obj, deps, :env).join("\n")
  end
end
