RedmineApp::Application.routes.draw do
  match 'view_ppp', :to => 'view_ppp#index'
  match 'view_ppp/:user_id', :to => 'view_ppp#index'
end