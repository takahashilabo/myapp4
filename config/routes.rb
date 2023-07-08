Rails.application.routes.draw do
  get 'bookmarks/index', to: 'bookmarks#index'
  get 'bookmarks/new', to: 'bookmarks#new'
  post 'bookmarks/create', to: 'bookmarks#create'
  root 'bookmarks#index'
end
