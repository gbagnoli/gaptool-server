libpath = File.expand_path(File.join(File.dirname(__FILE__), "..", "lib"))
$:.unshift(libpath)
require "#{libpath}/app.rb"
