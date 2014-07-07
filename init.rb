#!/bin/env ruby
# encoding: utf-8

require 'redmine'

Redmine::Plugin.register :redmine_view_ppp do
  name 'Персональный производственный план'
  author 'Иван Петухов'
  description 'Отображение персонального производственного плана пользователя'
  version '0.0.1'
  url ''
  author_url ''
  
  menu :top_menu, :view_ppp,
    {:controller => 'view_ppp', :action => 'index'}, :caption => :view_ppp, :after => :news

end
