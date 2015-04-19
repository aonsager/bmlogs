class HomeController < ApplicationController
  def index
    redirect_to user_path(params[:user_id]) if params.has_key? :user_id
  end
end
