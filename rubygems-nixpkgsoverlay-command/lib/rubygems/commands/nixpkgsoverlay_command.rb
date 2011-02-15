require 'net/http'
require 'rubygems/command'
require 'rubygems/doc_manager'
require 'rubygems/install_update_options'
require 'rubygems/dependency_installer'
require 'rubygems/local_remote_options'
require 'rubygems/validator'
require 'rubygems/exceptions'
require 'rubygems/version_option'
require 'rubygems/version'
require 'open3'

##
# see initialize to find out what this file is about

class Gem::Commands::NixpkgsoverlayCommand < Gem::Command

  include Gem::VersionOption
  include Gem::LocalRemoteOptions
  include Gem::InstallUpdateOptions

  def initialize
    @description = 'create .nix file containing all data suitable for creating ruby gem derivations'
    defaults = Gem::DependencyInstaller::DEFAULT_OPTIONS.merge({
    })
    super 'nix', @description, defaults
    add_prerelease_option "to be installed. (Only for listed gems)"

    @cache_dir = options[:cache_dir] || options[:install_dir] || Gem.dir
    @gem_hashes_cache =  "~/.gem/nix-gem-hashes"
  end

  def description # :nodoc:
    <<-EOF
      #{@description}
      gem nix target-file.nix
    EOF
  end

  def usage # :nodoc:
    "gem nix target-file.nix"
  end

  def arguments # :nodoc:
    "target-file.nix       nix file to which the gem specifications will be written to"
  end

  def defaults_str # :nodoc:
    ""
  end

  def execute

      puts "hash cache file is #{@gem_hashes_cache}"

      @target_nix = options[:args][0]

      # by default the latest versions will be fetched only. Use this file to
      # specify additional versions to be fetched
      @additional_gems_file = options[:args][1]

      if @target_nix.nil?
        throw "first argument must point to $NIXPKGS_RUBY_OVERLAY/pkgs/ruby-packages.nix"
      end

      all = options[:all]

      # should be taken from options!
      @prerelease = false;

      failed = []

      withHashCash { |cache|
        File.open(@target_nix, "wb") { |target_nix|

          target_nix.write("# file was generated automatically by patched rubygems\n")
          target_nix.write("# contents: platform.name.version = derivation info \n")
          target_nix.write("# depndency [foo [[>=  2.0], [<= 4]]] means both version constraints must match \n")
          target_nix.write("{fetchurl}:\n")
          target_nix.write("{\n")

          # fetches all sources defined in Gem::sources
          # File.open("/tmp/all", "rb") { |file| all = Marshal.load(file) }
          #  On Mon Feb 14 18:15:47 CET 2011  all packages are around 100.000,
          #  the latest only about 20.000
          #  100.000 is quite a lot... so maybe use the latest + a set of
          #  elected versions ?
          all = Gem::SpecFetcher.fetcher.list(true, @prerelease) # (all = false, prerelease = false)
          File.open("/tmp/all", "wb") { |file| Marshal.dump(all, file) }

          # get additional gems:


          # now the fun begins:
          
          nr = 1
          total_count = all.map {|suri, list| list.count }.inject(:+)

          did = Hash.new()

          all.each_pair {|uri, spec_list|
            spec_list.each {|spec|
              begin

                p "processing #{spec} #{nr}/#{total_count} = #{sprintf('%.1f', 100.to_f * nr / total_count)}%"
                nr +=1

                next if spec.nil?

                # fetch spec
                begin   
                  spec = Gem::SpecFetcher.fetcher.fetch_spec(spec,uri)
                rescue Exception => e   
                  puts e.message   
                  e.backtrace.each {|b| puts b }
                  failed << "failed fetching spec: #{spec} #{uri}"
                  next
                end   
                did[spec.full_name] = [] unless did.has_key? spec.full_name
                did[spec.full_name] << spec
                next if did[spec.full_name].length > 1

                p "processing #{spec.full_name}"

                if !cache.has_key?(spec.full_name)
                  p "no hash, fetching gem #{spec.full_name}"
                  # try to get hash by asking for it on
                  # production.cf.rubygems.org mirror which is poweder by
                  # CloudFront CDN which is using md5 as ETag (Thanks to Jeremy Hinegardner)

                  hash = `curl --silent -I http://production.cf.rubygems.org/gems/#{spec.full_name}.gem | sed -n 's/ETag: "\\(.*\\)"/\\1/p'`.split("\n")[0]
                  hash = hash.strip unless hash.nil?

                  if hash.nil? then
                    p "curl -I failed. runnig md5 on #{spec.full_name}"
                    gem_file = Gem::RemoteFetcher.fetcher.download spec, uri, @cache_dir
                    hash = `nix-hash --flat --type md5 #{gem_file}`.split("\n")[0].strip
                  end
                  p "hash is #{hash}"

                  raise Exception.new("couldn't determine hash for #{uri} #{gem.full_name}") if hash == "" or hash.nil?
                  cache[spec.full_name] = hash
                end

                # deps_to_s = lambda {|list| list.map {|n| "\"#{n.name} #{n.version_requirements}\"" }.join(", ") }
                deps_to_s = lambda {|list| list.map {|r|  "[\"#{r.name}\"  [#{r.requirement.requirements.map {|r| assert(r.length ==2); "[\"#{r[0]}\" \"#{r[1]}\"]"}.join(" ") }]]" } }
                remote_gem_path = uri + "gems/#{spec.file_name}"

                ld = spec.description.nil? ? " no description " : spec.description.strip

                item = "
                  \"#{spec.platform}\".\"#{spec.name}\".\"#{spec.version.to_s}\" = {
                     name = \"#{spec.name}\";
                     version = \"#{spec.version}\";
                     bump = \"#{spec.version.bump}\";
                     platform = \"#{spec.platform}\";
                     developmentDependencies = [ #{deps_to_s.call(spec.development_dependencies) } ];
                     runtimeDependencies = [ #{deps_to_s.call(spec.runtime_dependencies) } ];
                     dependencies =        [ #{deps_to_s.call(spec.dependencies)} ];
                     src = fetchurl {
                       url = \"#{remote_gem_path}\";
                       md5 = \"#{cache[spec.full_name]}\";
                     };
                     meta = {
                       homepage = #{nixstr(spec.homepage)};
                       license = [#{spec.licenses.map{|l| "\"#{l}\""}.join(" ") }]; # one of ?
                       #{nixdescription spec}
                       longDescription = ''\n#{ ld.gsub("''","'''").gsub('${',"''$") }\n'';
                     };
                  };\n"
                  item = item.gsub(/^ {14}/,'')

              target_nix.write("#{item}\n")
            rescue Exception => e   
              puts "failure for #{spec.to_s}"
              puts e.message   
              e.backtrace.each {|b| puts b }

              failed << "failure for #{spec.to_s}"
              failed << e.to_s
              # TODO:
              throw e if ["ajp-rails","oz","ttk","ruby-ajp"].index(spec.name).nil?
            end
            } # each spec
          }   # each uri

          target_nix.write("}\n")
          # did.each_pair{|key, list| if  list.length > 1 then p "key #{key}"; list.map {|b| print  "===> \n#{b.to_yaml}YAML_END\n" } end }
          did.each_pair{|key, list|
            if  list.length > 1 && ! list.map{|b| b.to_yaml}.inject(:==) then
              warn = "# WARNING: multiple definitions of #{list[0].full_name} which differ in .to_yaml\n"
              failed << warn
              target_nix.write(warn)
            end
          }

        } # file

        print "file written to #{@target_nix}"
      } # cache

    if failed.length > 0
      puts "\n\nFAILURS #{failed.length}"
      failed.each {|b| puts b }
    end

    rescue Exception => e   
      puts "nix command failed. Exception and trace:"
      puts e.message   
      e.backtrace.each {|b| puts b }
      raise e
  end

  def withHashCash
    cache_file = File.expand_path(@gem_hashes_cache)
    hash = nil
    if File.exists? cache_file then
      File.open(cache_file, "rb") { |file| hash = Marshal.load(file) }
    else
      hash = Hash.new
    end
    yield hash
  ensure
    File.open(cache_file, "wb") { |file| Marshal.dump(hash, file) }
  end

  def nixstr(s)
    if s.nil? then
      "\"\""
    else
      "\"#{s.gsub(/([$"\\])/,'\\\\\1')}\""
    end
  end

  def nixdescription(spec)
    desc_from_spec = spec.description
    desc_from_spec = "no description for #{spec.file_name}" if desc_from_spec.nil?
    desc = desc_from_spec.sub(/[.].*/,'') # only keep first sentence
    desc = desc.length > 120 \
      ? "description = #{ nixstr(desc[0..120]) }; # cut to 120 chars" \
      : "description = #{ nixstr(desc) };"
    desc = desc.sub(/'';$/,"[...]'';") if desc != desc_from_spec
    desc.gsub("\n"," ") # no \ns in description
  end

  def assert(p)
    if !p
      raise Exception.new("assertion failed")
    end
  end

end
