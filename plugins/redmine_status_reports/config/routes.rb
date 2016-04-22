# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
RedmineApp::Application.routes.draw do
  match 'status_reports/report', :to => 'status_reports#report', :via => [:get, :post]
  match 'status_reports/report_activities', :to => 'status_reports#report_activities', :via => [:get, :post]
  match 'status_reports/entries_without_answer_report', :to => 'status_reports#entries_without_answer_report', :via => [:get, :post]
  match 'status_reports/report_politicas_cierre', :to => 'status_reports#report_politicas_cierre', :via => [:get, :post]
  match 'status_reports/report_polls', :to => 'status_reports#report_polls', :via => [:get, :post]
  match 'status_reports/report_polls_pendientes', :to => 'status_reports#report_polls_pendientes', :via => [:get, :post]
end