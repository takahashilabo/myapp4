Rails.application.routes.draw do
  get 'bookmark/index', to: 'bookmark#index'
  root 'bookmark#index'
end
