# encoding: utf-8
require 'bson_ext'
require 'mongo'
module MongodbHelpers
  def collectioncount(dbcollections)
    @remote_mongodb = Mongo::MongoClient.new(
      'localhost' || $redis.hget('config', 'remotemongo:host'),
      27017 || $redis.hget('config', 'remotemongo:port'),
    )
    result = Hash.new
    dbcollections.keys.each do |db|
      @db = @remote_mongodb[db]
      count = Hash.new
      dbcollections[db].each do |collection|
        count.merge!(collection => @db[collection].stats['count'])
      end
      result.merge!(db => count)
    end
    return result
  end
end
