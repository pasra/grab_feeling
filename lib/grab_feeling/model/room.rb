#-*- coding: utf-8 -*-
require_relative '../db.rb'

class Room < ActiveRecord::Base
  has_many :players, dependent: :destroy
  has_many :statuses
  has_many :logs
  has_one :drawer, :class_name => "Player", :foreign_key => "drawer_id"

  validates_uniqueness_of :unique_id

  def session_key
    :"player_#{self.id}"
  end

  def add_system_log *args
    obj = {room_id: self.id}
    I18n.available_locales.each do |locale|
      I18n.with_locale locale do
        obj[locale] = I18n.t(*args)
      end
    end
    self.statuses.create(ja: obj[:ja], en: obj[:en])
    GrabFeeling::Communicator.notify :system_log, obj
    self
  end
end
