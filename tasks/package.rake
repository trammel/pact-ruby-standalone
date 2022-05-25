# For Bundler.with_clean_env
require 'bundler/setup'

PACKAGE_NAME = "pact"
VERSION = File.read('VERSION').strip
TRAVELING_RUBY_VERSION = "20210206-2.4.10"
JSON_VERSION="2.5.1"

desc "Package pact-ruby-standalone for OSX and Linux x86_64"
task :package => ['package:linux:x86_64', 'package:osx']

namespace :package do
  namespace :linux do
    desc "Package pact-ruby-standalone for Linux x86_64"
    task :x86_64 => [
      :bundle_install,
      "build/traveling-ruby-#{TRAVELING_RUBY_VERSION}-linux-x86_64.tar.gz",
      "build/traveling-ruby-#{TRAVELING_RUBY_VERSION}-linux-x86_64-json-#{JSON_VERSION}.tar.gz"
    ] do
      create_package(TRAVELING_RUBY_VERSION, "linux-x86_64", "linux-x86_64", :unix)
    end
  end

  desc "Package pact-ruby-standalone for OS X"
  task :osx => [
    :bundle_install,
    "build/traveling-ruby-#{TRAVELING_RUBY_VERSION}-osx.tar.gz",
    "build/traveling-ruby-#{TRAVELING_RUBY_VERSION}-osx-json-#{JSON_VERSION}.tar.gz"
  ] do
    create_package(TRAVELING_RUBY_VERSION, "osx", "osx", :unix)
  end

  desc "Install gems to local directory"
  task :bundle_install do
    if RUBY_VERSION !~ /^2\.4\./
      abort "You can only 'bundle install' using Ruby 2.4, because that's what Traveling Ruby uses."
    end
    sh "rm -rf build/tmp"
    sh "mkdir -p build/tmp"
    sh "cp packaging/Gemfile packaging/Gemfile.lock build/tmp/"
    sh "mkdir -p build/tmp/lib/pact/mock_service"
    # sh "cp lib/pact/mock_service/version.rb build/tmp/lib/pact/mock_service/version.rb"
    Bundler.with_clean_env do
      sh "cd build/tmp && env BUNDLE_IGNORE_CONFIG=1 bundle install --path ../vendor --without development"
      generate_readme
    end
    sh "rm -rf build/tmp"
    sh "rm -rf build/vendor/*/*/cache/*"
  end

  task :generate_readme do
    Bundler.with_clean_env do
      sh "mkdir -p build/tmp"
      sh "cp packaging/Gemfile packaging/Gemfile.lock build/tmp/"
      sh "cd build/tmp && env BUNDLE_IGNORE_CONFIG=1 bundle install --path ../vendor --without development"
      generate_readme
    end
  end
end

file "build/traveling-ruby-#{TRAVELING_RUBY_VERSION}-linux-x86_64.tar.gz" do
  download_runtime(TRAVELING_RUBY_VERSION, "linux-x86_64")
end

file "build/traveling-ruby-#{TRAVELING_RUBY_VERSION}-osx.tar.gz" do
  download_runtime(TRAVELING_RUBY_VERSION, "osx")
end

file "build/traveling-ruby-#{TRAVELING_RUBY_VERSION}-linux-x86_64-json-#{JSON_VERSION}.tar.gz" do
  download_native_extension("linux-x86_64", "json-#{JSON_VERSION}")
end

file "build/traveling-ruby-#{TRAVELING_RUBY_VERSION}-osx-json-#{JSON_VERSION}.tar.gz" do
  download_native_extension("osx", "json-#{JSON_VERSION}")
end

def create_package(version, source_target, package_target, os_type)
  package_dir = "#{PACKAGE_NAME}"
  package_name = "#{PACKAGE_NAME}-#{VERSION}-#{package_target}"
  sh "rm -rf #{package_dir}"
  sh "mkdir #{package_dir}"
  sh "mkdir -p #{package_dir}/lib/app"
  sh "mkdir -p #{package_dir}/bin"
  sh "cp build/README.md #{package_dir}"
  sh "cp packaging/pact*.rb #{package_dir}/lib/app"

  # sh "cp -pR lib #{package_dir}/lib/app"
  sh "mkdir #{package_dir}/lib/ruby"
  sh "tar -xzf build/traveling-ruby-#{version}-#{source_target}.tar.gz -C #{package_dir}/lib/ruby"
  # From https://curl.se/docs/caextract.html
  sh "cp packaging/cacert.pem #{package_dir}/lib/ruby/lib/ca-bundle.crt"

  Dir.chdir('packaging'){ Dir['pact*.sh'] }.each do | name |
    sh "cp packaging/#{name} #{package_dir}/bin/#{name.chomp('.sh')}"
  end

  sh "cp -pR build/vendor #{package_dir}/lib/"
  sh "cp packaging/Gemfile packaging/Gemfile.lock #{package_dir}/lib/vendor/"
  sh "mkdir #{package_dir}/lib/vendor/.bundle"
  sh "cp packaging/bundler-config #{package_dir}/lib/vendor/.bundle/config"
  sh "tar -xzf build/traveling-ruby-#{TRAVELING_RUBY_VERSION}-#{source_target}-json-#{JSON_VERSION}.tar.gz -C #{package_dir}/lib/vendor/ruby"

  remove_unnecessary_files package_dir

  if !ENV['DIR_ONLY']
    sh "mkdir -p pkg"

    if os_type == :unix
      sh "tar -czf pkg/#{package_name}.tar.gz #{package_dir}"
    else
      sh "zip -9rq pkg/#{package_name}.zip #{package_dir}"
    end

    sh "rm -rf #{package_dir}"
  end
end

def remove_unnecessary_files package_dir
  ## Reduce distribution - https://github.com/phusion/traveling-ruby/blob/master/REDUCING_PACKAGE_SIZE.md
  # Remove tests
  sh "rm -rf #{package_dir}/lib/vendor/ruby/*/gems/*/test"
  sh "rm -rf #{package_dir}/lib/vendor/ruby/*/gems/*/tests"
  sh "rm -rf #{package_dir}/lib/vendor/ruby/*/gems/*/spec"
  sh "rm -rf #{package_dir}/lib/vendor/ruby/*/gems/*/features"
  sh "rm -rf #{package_dir}/lib/vendor/ruby/*/gems/*/benchmark"

  # Remove documentation"
  sh "rm -f #{package_dir}/lib/vendor/ruby/*/gems/*/README*"
  sh "rm -f #{package_dir}/lib/vendor/ruby/*/gems/*/CHANGE*"
  sh "rm -f #{package_dir}/lib/vendor/ruby/*/gems/*/Change*"
  sh "rm -f #{package_dir}/lib/vendor/ruby/*/gems/*/COPYING*"
  sh "rm -f #{package_dir}/lib/vendor/ruby/*/gems/*/LICENSE*"
  sh "rm -f #{package_dir}/lib/vendor/ruby/*/gems/*/MIT-LICENSE*"
  sh "rm -f #{package_dir}/lib/vendor/ruby/*/gems/*/TODO"
  sh "rm -f #{package_dir}/lib/vendor/ruby/*/gems/*/*.txt"
  sh "rm -f #{package_dir}/lib/vendor/ruby/*/gems/*/*.md"
  sh "rm -f #{package_dir}/lib/vendor/ruby/*/gems/*/*.rdoc"
  sh "rm -rf #{package_dir}/lib/vendor/ruby/*/gems/*/doc"
  sh "rm -rf #{package_dir}/lib/vendor/ruby/*/gems/*/docs"
  sh "rm -rf #{package_dir}/lib/vendor/ruby/*/gems/*/example"
  sh "rm -rf #{package_dir}/lib/vendor/ruby/*/gems/*/examples"
  sh "rm -rf #{package_dir}/lib/vendor/ruby/*/gems/*/sample"
  sh "rm -rf #{package_dir}/lib/vendor/ruby/*/gems/*/doc-api"
  sh "find #{package_dir}/lib/vendor/ruby -name '*.md' | xargs rm -f"

  # Remove misc unnecessary files"
  sh "rm -rf #{package_dir}/lib/vendor/ruby/*/gems/*/.gitignore"
  sh "rm -rf #{package_dir}/lib/vendor/ruby/*/gems/*/.travis.yml"

  # Remove leftover native extension sources and compilation objects"
  sh "rm -f #{package_dir}/lib/vendor/ruby/*/gems/*/ext/Makefile"
  sh "rm -f #{package_dir}/lib/vendor/ruby/*/gems/*/ext/*/Makefile"
  sh "rm -f #{package_dir}/lib/vendor/ruby/*/gems/*/ext/*/tmp"
  sh "find #{package_dir}/lib/vendor/ruby -name '*.c' | xargs rm -f"
  sh "find #{package_dir}/lib/vendor/ruby -name '*.cpp' | xargs rm -f"
  sh "find #{package_dir}/lib/vendor/ruby -name '*.h' | xargs rm -f"
  sh "find #{package_dir}/lib/vendor/ruby -name '*.rl' | xargs rm -f"
  sh "find #{package_dir}/lib/vendor/ruby -name 'extconf.rb' | xargs rm -f"
  sh "find #{package_dir}/lib/vendor/ruby/*/gems -name '*.o' | xargs rm -f"
  sh "find #{package_dir}/lib/vendor/ruby/*/gems -name '*.so' | xargs rm -f"
  sh "find #{package_dir}/lib/vendor/ruby/*/gems -name '*.bundle' | xargs rm -f"

  # Remove Java files. They're only used for JRuby support"
  sh "find #{package_dir}/lib/vendor/ruby -name '*.java' | xargs rm -f"
  sh "find #{package_dir}/lib/vendor/ruby -name '*.class' | xargs rm -f"

  # Ruby Docs
  sh "rm -rf #{package_dir}/lib/ruby/lib/ruby/*/rdoc*"

  # Website files
  sh "find #{package_dir}/lib/vendor/ruby -name '*.html' | xargs rm -f"
  sh "find #{package_dir}/lib/vendor/ruby -name '*.css' | xargs rm -f"
  sh "find #{package_dir}/lib/vendor/ruby -name '*.svg' | xargs rm -f"

  # Uncommonly used encodings
  sh "rm -f #{package_dir}/lib/ruby/lib/ruby/*/*/enc/cp949*"
  sh "rm -f #{package_dir}/lib/ruby/lib/ruby/*/*/enc/euc_*"
  sh "rm -f #{package_dir}/lib/ruby/lib/ruby/*/*/enc/shift_jis*"
  sh "rm -f #{package_dir}/lib/ruby/lib/ruby/*/*/enc/koi8_*"
  sh "rm -f #{package_dir}/lib/ruby/lib/ruby/*/*/enc/emacs*"
  sh "rm -f #{package_dir}/lib/ruby/lib/ruby/*/*/enc/gb*"
  sh "rm -f #{package_dir}/lib/ruby/lib/ruby/*/*/enc/big5*"
  # sh "rm -f #{package_dir}/lib/ruby/lib/ruby/*/*/enc/windows*"
  # sh "rm -f #{package_dir}/lib/ruby/lib/ruby/*/*/enc/utf_16*"
  # sh "rm -f #{package_dir}/lib/ruby/lib/ruby/*/*/enc/utf_32*"
end

def generate_readme
  template = File.absolute_path("packaging/README.md.template")
  script = File.absolute_path("packaging/generate_readme_contents.rb")
  Bundler.with_clean_env do
    sh "cd build/tmp && env VERSION=#{VERSION} bundle exec ruby #{script} #{template} > ../README.md"
  end
end

def download_runtime(version, target)
  sh "cd build && curl -L -O --fail " +
    "http://d6r77u77i8pq3.cloudfront.net/releases/traveling-ruby-#{version}-#{target}.tar.gz"
end

def download_native_extension(target, gem_name_and_version)
  sh "cd build && curl -L --fail -o traveling-ruby-#{TRAVELING_RUBY_VERSION}-#{target}-#{gem_name_and_version}.tar.gz " +
    "https://d6r77u77i8pq3.cloudfront.net/releases/traveling-ruby-gems-#{TRAVELING_RUBY_VERSION}-#{target}/#{gem_name_and_version}.tar.gz"
end
