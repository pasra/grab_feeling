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
    :"player_#{self.id}"
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

  def next_round(is_first=false)
    ActiveRecord::Base.transaction do
      dic_rand = rand(self.dictionaries.count)+self.dictionaries.first.id
      dictionary = self.dictionaries.where('id >= ?', dic_rand)

      theme = dictionary.where('id >= ?', rand(dictionary.count)).first

      if is_first || !(last_round = self.rounds.last)
        drawer = self.players.first
      elsif (next_player = last_round.drawer.next_player)
        drawer = next_player
      elsif (self.round + 1) > self.max_round
        self.round = 1
        self.in_game = false
        self.save!
        return nil
      else
        self.round += 1
        self.save!
        drawer = self.players.first
      end

      time = Time.now

      next_at = if !next_player.next_player && (self.round + 1) > self.max_round
                  time+Config["operation"]["turn"]
                else
                  time+Config["operation"]["turn"]+Config["operation"]["interval"]
                end

      self.rounds.create! topic: Config["theme_opening"]["hider"] * theme.text.size,
                          theme_id: theme.id, drawer_id: drawer.id,
                          started_at: time, next_at: next_at
    end
  end
end
