#-*- coding: utf-8 -*-
require 'sinatra/base'
require 'sinatra/reloader'
require 'digest/sha1'
require 'json'

module GrabFeeling
  class SocketApp < Sinatra::Base
    @@sockets = {}
    @@event_hooks = {}
    @@logger = Logger.new(STDOUT)

    def self.hook_event(name,&block)
      (@@event_hooks[name] ||= []) << block
    end

    hook_event :hi do
      @@logger.info("Hi!")
    end

    hook_event :hi do
      @@logger.info("Hello!")
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
      use Rack::Session::Cookie,
        :expire_after => 60 * 60 * 24 * 12
    end

    post "/event/:name" do
      obj = JSON.parse(request.body)
      EM.defer do
        @@logger.info("Event received: #{name}")
        @@event_hooks[name].each{|x| x[obj] }
      end
    end
  end
end

