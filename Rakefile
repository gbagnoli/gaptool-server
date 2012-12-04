# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "gaptool-server"
  gem.homepage = "http://github.com/mattbailey/gaptool-server"
  gem.license = "MIT"
  gem.summary = %Q{gaptool-server for managing cloud resources}
  gem.description = %Q{gaptool-server for managing cloud resources}
  gem.email = "m@mdb.io"
  gem.authors = ["Matt Bailey"]
  gem.executables = ['gaptool-server']
  gem.default_executable = 'gaptool-server'
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

task :default => :test

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "gaptool-server #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

namespace :config do
  require 'redis'
  require 'yaml'
  ENV['REDIS_HOST'] = 'localhost' unless ENV['REDIS_HOST']
  ENV['REDIS_PORT'] = '6379' unless ENV['REDIS_PORT']
  ENV['REDIS_PASS'] = nil unless ENV['REDIS_PASS']
  @redis = Redis.new(:host => ENV['REDIS_HOST'], :port => ENV['REDIS_PORT'], :password => ENV['REDIS_PASS'])
  $stderr.puts "env vars REDIS_HOST, REDIS_PORT, and REDIS_PASS should all be set or\ndefaults of localhost:6379 with no password will be used"

  task :import do
    data = YAML::Parser($stdin)
    puts data
  end
  task :delete do
    print "Delete ALL existing data (y/N)? "
    delete = gets.chomp
    hashes = [
      'sg:us-east-1',
      'sg:us-west-1',
      'sg:us-west-2',
      'sg:ap-northeast-1',
      'sg:ap-southeast-1',
      'sg:ap-southeast-2',
      'sg:eu-west-1',
      'sg:sa-east-1',
      'config',
      'amis',
      'users',
    ]

    if delete == 'y'
      @redis.keys("*") do |key|
        @redis.del key
      end
    end

  end

  task :dump do
    dump = Hash.new
    @redis.keys("*").each do |key|
      puts key
      if @redis.type(key) == 'hash'
        dump.merge!({ key => @redis.hgetall(key) })
      else
        dump.merge!({ key => @redis.get(key) })
      end
    end
    puts dump.to_yaml
  end

end
