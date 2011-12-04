#-*- coding: utf-8 -*-
require 'eventmachine'
require 'em-websocket'
require_relative './socket_pool.rb'
require_relative './app_ws.rb'

module GrabFeeling
  class SocketApp
    EM.next_tick do

    ActiveRecord::Base.connection_pool.with_connection do
      ActiveRecord::Base.transaction do
        Player.all.each do |player|
          player.update_attributes! online: false
        end
      end
    end


      ws_opt = if Config["websocket"] && Config["websocket"]["socket"]
                 {host: Config["websocket"]["socket"], port: nil}
               else
                 Config["websocket"] ||= {}
                 {host: Config["websocket"]["host"] || "0.0.0.0",
                  port: Config["websocket"]["port"] || 4566}
               end
      EM.defer { EM::WebSocket.start(ws_opt, &(development? ? ->(ws){@@websocket[ws]} : @@websocket)) }
      @@scheduler ||= Scheduler.new(@@pool,development?).resume
    end
  end
end

