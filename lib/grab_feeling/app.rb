#-*- coding: utf-8 -*-
require 'sinatra/base'
require 'sinatra/reloader'
require 'digest/sha1'
require_relative './helper.rb'

module GrabFeeling
  class App < Sinatra::Base
    configure :development do
      register Sinatra::Reloader
    end

    configure do
      helpers GrabFeeling::Helper
      set :root, File.expand_path("#{File.dirname(__FILE__)}/../..")
      set :public_folder => Proc.new { File.join(root, 'public') }
      set :views => Proc.new { File.join(root, 'views') }
      set :default_locale, 'ja'
      ::I18n.load_path += Dir["#{root}/i18n/*.yml"]
      use Rack::Session::Cookie,
        :expire_after => 60 * 60 * 24 * 12
    end

    get '/' do
      @rooms = Room.all
      haml :index
    end

    get '/create' do
      haml :create
    end

    post '/create' do
      room = params[:room].dup
      room[:watchable] = (room[:watchable] == '1')
      room[:listed] = (room[:listed] == '1')
      room[:join_key] &&
        room[:join_key] = Digest::SHA1.hexdigest(Config["key_salt"]+room[:join_key])
      room[:watch_key] &&
        room[:watch_key] = Digest::SHA1.hexdigest(Config["key_salt"]+room[:watch_key])

      room.delete(:drawer_id)
      room.delete(:unique_id)

      @room = Room.new(room)

      if @room.save
        uid_a = Digest::SHA1.hexdigest("#{@room.id}#{Time.now.to_f}#{rand}").chars.to_a
        uid = [6.times.map{ uid.shift }.join]+uid
        @room.unique_id = uid.inject do |r,i|
          if @room.first(:conditions => ["unique_id = ?", r = r+i])
            r
          else; break r
          end
        end
        @room.save!
        redirect "/g/#{@room.unique_id}"
      else
        haml :create
      end
    end

    get '/g/:id' do
      @room = Room.find_by_unique_id(params[:id])
      return halt(404) unless @room

      if session[@room.session_key]
        @player = Player.find_by_id(session[@room.session_key])
        haml :room
      else
        haml :room_entrance
      end
    end

    post '/g/:id/join' do
      @room = Room.find_by_unique_id(params[:id])
      return halt(404) unless @room
      return redirect("/g/#{@room.unique_id}") if session[@room.session_key]

      player = params[:player].dup
      player[:token] = Digest::SHA1.hexdigest(3.times.map{rand(100000000000)}.join)
      @player = @room.players.build(player)

      if @player.save
        if @room.players[0].id == @player.id
          @player.admin = true
          @player.save!
        end
        session[@room.session_key] = @player.id
        Communicator.notify :join, room_id: @room.id, player_id: @player.id,
                                   player_name: @player.name
        room.add_system_log :player_joined, name: @player.name
        redirect "/g/#{@room.unique_id}"
      else
        haml :room_entrance
      end
    end

    post '/g/:id/leave' do
      @room = Room.find_by_unique_id(params[:id])
      return halt(404) unless @room
      return redirect("/g/#{@room.unique_id}") unless session[@room.session_key]

      @player = Player.find_by_id(session[@room.session_key])
      @room.players.delete(@player, :dependent => :destroy)
      session[@room.session_key] = nil
      Communicator.notify :leave, room_id: @room.id, player_id: @player.id,
                                 player_name: @player.name
      room.add_system_log :player_left, name: @player.name
      if @room.players.find(:all, :conditions => ['admin = true']).empty?
        @room.ended = true
        @room.save!

        Communicator.notify :room_end, room_id: @room.id

        redirect "/"
      else
        redirect "/g/#{@room.id}"
      end
    end

    get '/g/:id.json' do
      @room = Room.find_by_unique_id(params[:id])
      return halt(404) unless @room
      return redirect("/g/#{@room.unique_id}") unless session[@room.session_key]

      content_type :json
      json = {locale: I18n.locale, system_logs: @room.statuses(true).map{|l| {en: l.en, ja: l.ja } },
              logs: @room.logs(true).map{|l| {text: l.text, name: l.player.name, player_id: l.player.id} },
              players: @room.players.map{|pl| {name: pl.name, id: pl.id, point: pl.point} }}

      json.to_json
    end
  end
end
