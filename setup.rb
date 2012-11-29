#!/usr/bin/env ruby

require 'aws-sdk'

zones = [
  'us-east-1',
  'us-west-1',
  'us-west-2',
  'sa-east-1',
  'eu-west-1',
  'ap-southeast-1',
  'ap-northeast-1',
  'ap-southeast-2',
]

puts "This script will set up your gaptool-server, make sure you have the aws-sdk gem installed."
puts "Before getting started, either create a new IAM role with full access to EC2, or input your master AWS ID and Secret."
puts "Also ensure that you have an EMPTY redis server running somewhere avilable."
puts "Read the source of this script if you're worried about what it does with it."

print "Enter AWS ID: "
aws_id = gets.chomp
print "Enter AWS Secret: "
aws_secret = gets.chomp
print "Redis host: "
redis_host = gets.chomp
print "Redis port: "
redis_port = gets.chomp
print "Redis password (leave blank if none): "
redis_pass = gets.chomp

@redis = Redis.new(:host => redis_host, :port => redis_port, :password => redis_pass)

zones.each do |zone|
  # Run for each AZ
  AWS.config(:access_key_id => aws_id, :secret_access_key => aws_secret, :ec2_endpoint => "ec2.#{zone}.amazonaws.com")
  @ec2 = AWS::EC2.new
  @key = @ec2.key_pairs.create('gaptool-server')
  @private = @key.private_key
end


