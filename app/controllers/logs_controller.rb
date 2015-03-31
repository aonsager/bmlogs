class LogsController < ApplicationController
  before_filter :get_user

  def refresh
    response = HTTParty.get("https://www.warcraftlogs.com:443/v1/reports/user/#{@user}?api_key=#{ENV['API_KEY']}")
    logs = JSON.parse(response.body)
    logs.each do |log|
      if !Log.exists?(:id => log['id'])
        Log.create(
          id: log['id'],
          title: log['title'],
          zone: log['zone'],
          started_at: Time.at(log['start']/1000),
          ended_at: Time.at(log['end']/1000),
        )
      end
    end

    redirect_to action: :show
  end

  def show
    @logs = Log.order(started_at: :desc)
  end

  private

  def get_user
    @user = params[:user]
  end
end
