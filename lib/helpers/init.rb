# encoding: utf-8
require_relative 'partials'
GaptoolServer.helpers PartialPartials

require_relative 'nicebytes'
GaptoolServer.helpers NiceBytes

require_relative 'gaptool-base'
GaptoolServer.helpers GaptoolBaseHelpers

require_relative 'redis'
GaptoolServer.helpers RedisHelpers
