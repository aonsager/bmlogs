class HomeController < ApplicationController
  def index
    if params.has_key?(:report_id)
      if (/\// =~ params[:report_id]).nil?
        report_id = params[:report_id].strip
      else
        match = /\/reports\/(\w+)/.match(params[:report_id])
        if match.nil?
          flash[:danger] = "Invalid report ID"
          redirect_to root_path
          return
        else
          report_id = match[1]
        end
      end
      redirect_to report_path(report_id)
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

  def checkmywow

  end

  def logout
    session.delete :user_id
    session.delete :char_name
    redirect_to root_path
  end
end
