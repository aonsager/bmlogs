class HomeController < ApplicationController
  def index
    if params.has_key?(:report_id)
      redirect_to report_path(params[:report_id])
    elsif params.has_key?(:user_id)
      redirect_to user_path(params[:user_id])
    else
      session[:char_name] = params[:char_name] if params.has_key?(:char_name)
      if session.has_key?(:char_name)
        redirect_to search_players_path(session[:char_name])
      end
    end
  end

  def about
    
  end

  def logout
    session.delete :user_id
    session.delete :char_name
    redirect_to root_path
  end
end
