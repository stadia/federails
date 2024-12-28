Rails.application.routes.draw do
  resources :posts
  resources :comments
  devise_for :users

  mount Federails::Engine => '/'

  get '/', to: 'home#home'
end
