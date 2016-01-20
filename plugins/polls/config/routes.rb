# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

get 'polls', :to => 'polls#index'
post 'create', :to => 'polls#create'
post 'send_poll_by_mail', :to => 'polls#send_poll_by_mail'