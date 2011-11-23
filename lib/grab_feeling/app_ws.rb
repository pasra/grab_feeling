#-*- coding: utf-8 -*-
require 'sinatra/base'
require 'sinatra/reloader'
require 'digest/sha1'
require 'json'

module GrabFeeling
  class SocketApp < Sinatra::Base
    @@sockets = SocketPool.new
    @@event_hooks = {}
    @@logger = Logger.new(STDOUT)
    @@websocket = ->{}

    def self.hook_event(name,&block)
      (@@event_hooks[name] ||= []) << block
    end

    def self.websocket(&block)
      @@websocket = block
    end

    hook_event :hi do
      @@logger.info("Hi!")
    end

    hook_event :hi do
      @@logger.info("Hello!")
    end

    websocket do |socket|
      socket.onopen do
      end

      socket.onmessage do
      end

      socket.onclose do
      end

      socket.onerror do
      end
    end

    configure :development do
      register Sinatra::Reloader
    end

    configure do
      set :root, File.expand_path("#{File.dirname(__FILE__)}/../..")
      set :public_folder => Proc.new { File.join(root, 'public') }
      set :views => Proc.new { File.join(root, 'views') }
      set :default_locale, 'ja'
      ::I18n.load_path += Dir["#{root}/i18n/*.yml"]
      use Rack::Session::Cookie, :expire_after => 60*60*24*12

      ws_opt = if Config["websocket"] && Config["websocket"]["socket"]
                 {host: Config["websocket"]["socket"], port: nil}
               else
                 Config["websocket"] ||= {}
                 {host: Config["websocket"]["host"] || "0.0.0.0",
                  port: Config["websocket"]["port"] || 4566}
               end
      EM::WebSocket.start(ws_opt, &@@websocket)
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

  class SocketPool
    def initialize
      @pool = {}
      @pool_player= {}
      @sockets = {}
    end

    def find_by_socket(socket)
      @sockets[socket.__id__]
    end

    def find_by_room_id(room_id)
      @pool[room_id]
    end

    def find_by_player_id(player_id)
      @pool_player[player_id]
    end

    def add(room_id, player_id, socket)
      obj = {socket: socket, room_id: room_id, player_id: player_id}
      @pool[room_id] ||= {}
      @pool[room_id][player_id] = obj
      @pool_player[player_id] = obj
      @sockets[socket.__id__] = obj
      self
    end

    def remove(socket)
      remove_ find_by_socket(socket)
    end

    def remove_by_player_id(player_id)
      remove_ find_by_player_id(player_id)
    end

    private

    def remove_(obj)
      return nil unless obj
      @sockets.delete(obj[:socket].__id__)
      @pool[obj[:room_id]].delete(obj[:player_id])
      @pool_player.delete(obj[:player_id])
      self
    end
  end
end

