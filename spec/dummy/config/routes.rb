Rails.application.routes.draw do
  get 'hello_world', to: 'hello_world#index'

  get '/', to: redirect('/hello_world')
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
