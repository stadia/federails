Rails.application.routes.draw do
  devise_for :users

  resources :users, only: [:show]
  resources :posts
  resources :comments, except: [:index, :show, :new]

  mount Fedipub::Engine => '/'

  get '/', to: 'home#home'
end
