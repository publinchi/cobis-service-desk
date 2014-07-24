#encoding: utf-8

require_dependency 'issues_sidebar_status_reports_hook'

Redmine::Plugin.register :redmine_status_reports do
  name 'Redmine Status Reports plugin'
  author 'Publio Estupiñán'
  description 'This is a plugin for reporting status'
  version '0.0.1'
  url 'http://www.cobiscorp.com'
  author_url 'http://www.cobiscorp.com'
end
