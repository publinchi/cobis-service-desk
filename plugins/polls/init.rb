Redmine::Plugin.register :polls do
  name 'Polls plugin'
  author 'Publio Estupinan'
  description 'Plugin de Encuestas'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://www.cobiscorp.com'
  permission :polls, { :polls => [:index, :create] }, :require => :member
  
  menu :project_menu, :polls, { :controller => 'polls', :action => 'index' }, :caption => 'Polls', :after => :activity, :param => :project_id

  project_module :polls do
    permission :view_polls, :polls => :index
    permission :create_polls, :polls => :create
  end
end
