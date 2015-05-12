Dummy::Application.routes.draw do

  scope "v1" do
    resources :the_models, except: [:new, :edit] do
      member do
        put 'connect'
      end
      collection do
        get 'call_others'
      end
    end
  end

end
