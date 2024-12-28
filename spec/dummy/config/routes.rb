Rails.application.routes.draw do
  devise_for :users

  resources :posts
  resources :comments, except: [:index, :show, :new]

  mount Federails::Engine => '/'

  get '/', to: 'home#home'
end
