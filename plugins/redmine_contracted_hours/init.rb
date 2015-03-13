require 'redmine'

Redmine::Plugin.register :redmine_contracted_hours do
  name 'Redmine Contracted Hours plugin'
  author 'Carolina Sandoval'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'
  menu :admin_menu, :contracted_hours, { :controller => :contracted_hours, :action => :index }, :caption => :label_contracted_hour_plural
  
 
end



require_dependency 'issues_sidebar_contracted_hour_hook'
require_dependency 'projects_sidebar_contracted_hour_hook'
