#-*- coding: utf-8 -*-
require_relative '../db.rb'

class Round < ActiveRecord::Base
  belongs_to :room
  belongs_to :theme
  belongs_to :drawer, :class_name => "Player", :foreign_key => "drawer_id"

  def ends_at
    self.started_at + GrabFeeling::Config["operation"]["turn"]
  end
end
