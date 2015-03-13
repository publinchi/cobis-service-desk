# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

resources :contracted_hours
get  'contracted_hours' => 'contracted_hours#index'
get  'contracted_hours/index' => 'contracted_hours#index'
get  'contracted_hour/edit/:id' => 'contracted_hours#edit'
get  'contracted_hour/new' => 'contracted_hours#new'
post 'contracted_hours' => 'contracted_hours#create'
get  'contracted_hour/new' => 'contracted_hours#new'
get 'contracted_hour/time_entries' => 'contracted_hours#time_entries'
match 'contracted_hours/percentage' => 'contracted_hours#percentage'

#match 'contracted_hour/time_entries', :controller => 'contracted_hours', :action => 'time_entries', :via => [:get, :post]
match 'contracted_hours/update_form', :controller => 'contracted_hours', :action => 'update_form', :via => [:put, :post], :as => 'contracted_hour_form'
match 'contracted_hours/:id', :controller => 'contracted_hours', :action => 'destroy', :via => :post

RedmineApp::Application.routes.draw do
match 'contracted_hour/export_csv', :to => 'contracted_hours#export_csv', :via => [:get, :post]
end