class HomeController < ApplicationController
  def index
    if params.has_key?(:user_id) || session.has_key?(:user_id)
      user_id = params[:user_id] ||= session[:user_id]
      redirect_to user_path(user_id)
    end
  end

  def about
    
  end

  def logout
    session.delete :user_id
    redirect_to root_path
  end
end
