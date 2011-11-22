#-*- coding: utf-8 -*-
require 'json'
require 'eventmachine'
require 'em-http'

module GrabFeeling
  module Communicator
    @@logger = Logger.new(STDOUT)
    class << self
      def notify(name, hash={})
        @@logger.info "Notifying #{name}..."
        http = EM::HttpRequest.new(Config["url"]["websocket"]+"/event/#{name}") \
                              .post(body: hash.to_json)
        http.callback do
          if http.response_header.status == 200
            @@logger.info "Notified!"
          else
            @@logger.error "Failed to notify? #{http.response_header.status} returned"
          end
        end
        http.errback { @@logger.error "Failed to notify (errback)" }
        self
      end
    end
  end
end
