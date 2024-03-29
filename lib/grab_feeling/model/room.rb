#-*- coding: utf-8 -*-
require_relative '../db.rb'

class Room < ActiveRecord::Base
  has_many :players, dependent: :delete_all
  has_many :statuses, dependent: :delete_all
  has_many :logs, dependent: :delete_all
  has_many :rounds, dependent: :delete_all

  has_and_belongs_to_many :dictionaries

  validates_uniqueness_of :unique_id

  def session_key
    :"player_#{self.unique_id}"
  end

  def add_system_log *args
    obj = {room_id: self.id, type: :system_log}
    I18n.available_locales.each do |locale|
      I18n.with_locale locale do
        obj[locale] = I18n.t(*args)
      end
    end
    self.statuses.create(ja: obj[:ja], en: obj[:en])
    GrabFeeling::Communicator.notify :system_log, obj
    self
  end

  def next_round(pool, is_first=false, next_specified=false, next_=nil)
    ActiveRecord::Base.transaction do
     if is_first || !(last_round = self.rounds.last)
        drawer = self.players.where(online: true).first
        unless drawer
          self.add_system_log :no_online_players
          self.update_attributes! in_game: false, round: 1
          return nil
        end
      elsif (next_specified ? next_ : (next_player = last_round.drawer.next_player))
        drawer = next_player
      elsif (self.round + 1) > self.max_round
        self.update_attributes! in_game: false, round: 1
        return nil
      else
        self.round += 1
        self.save!
        drawer = self.players.where(online: true).first
        unless drawer
          self.add_system_log :no_online_players
          self.update_attributes! in_game: false, round: 1
          return nil
        end
      end

      dic_rand = rand(self.dictionaries.count)+self.dictionaries.first.id
      dictionary = self.dictionaries.where('id >= ?', dic_rand).first
      theme = dictionary.themes.where('id >= ?', rand(dictionary.themes.count)+dictionary.themes.first.id).first

      time = Time.now

      next_at = if !drawer.next_player && (self.round + 1) > self.max_round
                  time+GrabFeeling::Config["operation"]["turn"]
                else
                  time+GrabFeeling::Config["operation"]["turn"]+GrabFeeling::Config["operation"]["interval"]
                end

      round = self.rounds.create!(topic: GrabFeeling::Config["theme_opening"]["hider"] * theme.text.size,
                                  theme_id: theme.id, drawer_id: drawer.id,
                                  started_at: time, next_at: next_at)


      pool.broadcast self.id, type: :topic, topic: round.topic

      if _=pool.find_by_player_id(drawer.id)
        _[:socket].send({type: :topic, topic: theme.text}.to_json)
      end

      pool.broadcast self.id, type: :round,
                              started_at: round.started_at,
                              next_at: round.next_at,
                              ends_at: round.ends_at,
                              drawer: round.drawer.id

      self.add_system_log :round_start, drawer: round.drawer.name

      round
    end
  end
end
