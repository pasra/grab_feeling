#-*- coding: utf-8 -*-
require 'sinatra/base'
require 'sinatra/reloader'
require 'eventmachine'
require 'em-websocket'
require 'digest/sha1'
require 'json'
require_relative './socket_pool.rb'

module GrabFeeling
  class SocketApp < Sinatra::Base
    @@pool = SocketPool.new
    @@event_hooks = {}
    @@logger = Logger.new(STDOUT)
    @@websocket = ->{}
    @@image_requests = {}

    def self.hook_event(name,&block)
      (@@event_hooks[name] ||= []) << block
    end

    def self.websocket(&block)
      @@websocket = block
    end

    def ws_broadcast(room_id, msg={})
      message = msg.to_json
      @@pool.find_by_room_id(room_id).each do |pid,player|
        player[:socket].send message
      end
    end

    hook_event :join do |msg|
    end

    hook_event :leave do |msg|
    end

    websocket do |ws|
      ws.onopen do
        @@logger.info("#{ws.__id__}: opened")

        if !ws.request["query"] || !ws.request["query"]["player_id"] || !ws.request["query"]["token"]
          @@logger.info("#{ws.__id__}: needs more query")
          ws.send({type: "needs_token"})
        end

        if (player = Player.find_by_id(ws.request["query"]["player_id"])) && player.token == ws.request["query"]["token"]
          @@logger.info("#{ws.__id__}: Authorize succeeded")
          @@pool.add(player.room_id, player.id, ws)
          ws.send({type: "authorize_succeeded"}.to_json)
        else
          @@logger.info("#{ws.__id__}: Authorize failed")
          ws.send({type: "authorize_failed"}.to_json)
          ws.close_websocket
        end
      end

      ws.onmessage do |msg|
        json = JSON.parse(msg)
        @@logger.debug("#{ws.__id__}: json -> #{json}")

        ActiveRecord::Base.connection_pool.with_connection do
          i =  @@pool.find_by_socket(ws)
          case json["type"]
          when "image_request"
            @@logger.info("#{ws.__id__} requested a image...")

            players = (@@pool.find_by_room_id(i[:room_id]) - i)
            if players.empty?
              ws.send({type: "empty_image"})
              break
            end
            uploader = players.sample

            @@logger.error("#{ws.__id__} uploader == me?!") if uploader[:player_id] == i[:player_id]

            @@image_requests[i[:room_id]] ||= {requester: [], buffer: []}
            @@image_requests[i[:room_id]][:requester] << ws

            uploader[:socket].send({type: "image_request"}.to_json)
            ws.send({type: "image_requested"}.to_json)
          when"image"
            if @@image_requests[i[:room_id]]
              @@logger.info("#{ws.__id__} returned a image")
              message = {type: "image", image: json["image"], buffer: @@image_requests[i[:room_id]][:buffer]}.to_json
              @@image_requests.delete i[:room_id]
              @@image_requests[i[:room_id]][:requester].each do |sock|
                sock.send message
              end
            end
          when "chat"
            @@logger.info("#{ws.__id__} said \"#{i[:name]}: #{json["message"]}\" at room #{i[:room_id]}")
            ws_broadcast i[:room_id], type: "chat", from: i[:name], message: json["message"]
          when "draw"
            json["player_id"] = i[:player_id]
            @@image_requests[i[:room_id]][:buffer] << json if @@image_requests[i[:room_id]]
            ws_broadcast i[:room_id], json
          when "start"
          when "kick"
          when "skip"
          when "deop"
          when "op"
          end
        end
      end

      ws.onclose do
        @@pool.remove(ws)
        @@logger.info("#{ws.__id__}: closed")
      end

      ws.onerror do |e|
        @@pool.remove(ws)
        @@logger.error("#{ws.__id__}: closed (by error: #{e.message})")
      end
    end

    configure :development do
      register Sinatra::Reloader
    end

    configure do
      set :server => :thin
      set :root, File.expand_path("#{File.dirname(__FILE__)}/../..")
      set :public_folder => Proc.new { File.join(root, 'public') }
      set :views => Proc.new { File.join(root, 'views') }
      set :default_locale, 'ja'
      ::I18n.load_path += Dir["#{root}/i18n/*.yml"]
      use Rack::Session::Cookie, :expire_after => 60*60*24*12
    end

    post "/event/:name" do
      obj = JSON.parse(request.body.read)
      name = params[:name].to_sym
      EM.defer do
        @@logger.info("Event received: #{name}")
        (@@event_hooks[name] ||= []).each{|x| x[obj] }
      end
    end
  end
end

