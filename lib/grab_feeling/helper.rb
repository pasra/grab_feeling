#-*- coding: utf-8 -*-
require 'digest/sha1'

module GrabFeeling
  module Helper
    def t(*args)
      I18n.t *args
    end
  end
end
