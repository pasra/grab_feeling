#-*- coding: utf-8 -*-
require 'sinatra/base'
require 'sinatra/reloader'
require 'digest/sha1'
require 'i18n'
require_relative './helper'

module GrabFeeling
  class App < Sinatra::Base

    def call(env)
      ActiveRecord::Base.connection_pool.with_connection { ActiveRecord::Base.transaction {
        dup.call!(env)
      } }
    end

    helpers do
      def development?
        App.development?
      end
    end

    def load_transitions
      @@transitions = Hash[Dir["#{self.class_eval{root}}/i18n/*.yml"].map { |file|
        locale = File.basename(file)[0..-5]
        [locale.to_sym, YAML.load_file(file)[locale].to_json.dup.prepend("window.locale = \"#{I18n.locale}\"; window.localization = ")]
      }]
    end

    configure :development do
      register Sinatra::Reloader
      also_reload "#{File.dirname(__FILE__)}/**/*.rb"
    end

    configure do
      helpers GrabFeeling::Helper
      set :lock, true
      set :server => :thin
      set :root, File.expand_path("#{File.dirname(__FILE__)}/../..")
      set :public_folder => Proc.new { File.join(root, 'public') }
      set :views => Proc.new { File.join(root, 'views') }
      set :default_locale, 'ja'
      ::I18n.load_path += Dir["#{root}/i18n/*.yml"]
      use Rack::Session::Cookie,
        :expire_after => 60 * 60 * 24 * 12
    end

    configure :production, :test do
      load_transitions
    end

    before do
      if development?
        I18n.reload!
        load_transitions
      end

      if params[:locale]
        locale = params[:locale].to_sym

        if I18n.available_locales.include?(locale)
          I18n.locale = session[:locale] = locale
        end
      elsif session[:locale]
        I18n.locale = session[:locale].to_sym
      elsif request.env['HTTP_ACCEPT_LANGUAGE']
        locales = request.env['HTTP_ACCEPT_LANGUAGE'].split(/, ?/)
        locales.map! {|l| (_ = l.split(/;q=/)).size == 1 ? \
                          [_[0].to_sym,1.0] : [_[0].to_sym,_[1].to_f] }
        locales.select! {|l| I18n.available_locales.include?(l[0]) }
        if locales.empty?
          p :hi
          I18n.locale = Config["default_language"].to_sym || :ja
        else
          locales.sort_by! {|l| l[1] }.reverse!

          I18n.locale = locales.first[0]
        end
      else
        I18n.locale = Config["default_language"].to_sym || :ja
      end
    end

    get '/' do
      @rooms = Room.where(listed: true)
      haml :index
    end

    get '/create' do
      haml :create
    end

    post '/create' do
      room = Hash[params[:room].map{|k,v| [k.to_sym,v] }]

      [:watchable, :listed].each do |key|
        room[key] = (room[key] == '1')
      end

      [:join_key, :watch_key].each do |key|
        room[key] && room[key].empty? ? room.delete(key) :
          room[key] = Digest::SHA1.hexdigest(Config["key_salt"]+room[key])
      end

      room.delete(:drawer_id)
      room.delete(:unique_id)
      room.delete(:ended)
      room.delete(:started)
      room.delete(:ws_server)
      room.delete(:round)
      room.delete(:max_loop)
      room.delete(:loop)

      @room = Room.new(room)

      if params[:player][:name] && @room.save
        uid_a = Digest::SHA1.hexdigest("#{@room.id}#{Time.now.to_f}#{rand}").chars.to_a
        uid = [6.times.map{ uid_a.shift }.join]+uid_a
        @room.unique_id = uid.inject do |r,i|
          if Room.first(:conditions => ["unique_id = ?", r = r+i])
            r
          else; break r
          end
        end
        @room.save!
        raise "!?" unless create_player(@room, params[:player][:name])
        redirect "/g/#{@room.unique_id}"
      else
        haml :create
      end
    end

    get '/g/:id.json' do
      content_type :json

      @room = Room.find_by_unique_id(params[:id])
      return halt(404) unless @room
      return {error: "Who are you?"}.to_json unless session[@room.session_key]

      @player = @room.players.find_by_id(session[@room.session_key])
      return {error: "Who are you? wrong id?"}.to_json unless @player

      json = {locale: I18n.locale, system_logs: @room.statuses(true).map{|l| {en: l.en, ja: l.ja } },
              logs: @room.logs(true).map{|l| {message: l.text, name: l.player.name, player_id: l.player.id} },
              players: @room.players.map{|pl| {name: pl.name, id: pl.id, point: pl.point, you: pl.id == @player.id} },
              token: @player.token, debug: development?, websocket: Config["url"]["ws"],
              player_id: @player.id}

      json.to_json
    end

    get '/g/:id' do
      @room = Room.find_by_unique_id(params[:id])
      return halt(404) unless @room

      if session[@room.session_key]
        @player = Player.find_by_id(session[@room.session_key])
        @transition = @@transitions[I18n.locale] || @@transitions[Config["default_language"].to_sym]
        Communicator.notify :hi
        haml :room
      else
        haml :room_entrance
      end
    end

    post '/g/:id/join' do
      @room = Room.find_by_unique_id(params[:id])
      return halt(404) unless @room
      return redirect("/g/#{@room.unique_id}") if session[@room.session_key]

      @auth = @room.join_key ? (params[:room][:join_key] && @room.join_key == Digest::SHA1.hexdigest(Config["key_salt"]+params[:room][:join_key])) : true

      if @auth && create_player(@room, params[:player][:name])
        redirect "/g/#{@room.unique_id}"
      else
        haml :room_entrance
      end
    end

    post '/g/:id/leave' do
      @room = Room.find_by_unique_id(params[:id])
      return halt(404) unless @room
      return redirect("/g/#{@room.unique_id}") unless session[@room.session_key]

      @player = @room.players.find_by_id(session[@room.session_key])
      return halt(403) unless @player

      @room.players.delete @player
      session[@room.session_key] = nil
      Communicator.notify :leave, room_id: @room.id, player_id: @player.id,
                                 player_name: @player.name
      @room.add_system_log :player_left, name: @player.name

      if @room.players.find(:all, :conditions => ['admin = true']).empty?
        @room.ended = true
        @room.save!

        @room.add_system_log :room_end
        Communicator.notify :room_end, room_id: @room.id

        redirect "/"
      else
        redirect "/g/#{@room.unique_id}"
      end
    end

    if development?
      require 'coffee_script'
      get '/js/grab_feeling.js' do
        coffee :grab_feeling
      end

      get '/js/i18n.js' do
        coffee :i18n
      end
    end
  end
end
