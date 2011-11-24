#-*- coding: utf-8 -*-
require 'i18n'

module GrabFeeling
  module Helper
    def t(*args)
      I18n.t *args
    end
  end
end
