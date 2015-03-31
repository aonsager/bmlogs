class UsersController < ApplicationController
  before_filter :get_user

  def refresh
    response = HTTParty.get("https://www.warcraftlogs.com:443/v1/reports/user/#{@user_id}?api_key=#{ENV['API_KEY']}")
    reports = JSON.parse(response.body)
    reports.each do |report|
      if !Report.exists?(:report_id => report['id'])
        Report.create(
          report_id: report['id'],
          user_id: @user_id,
          title: report['title'],
          zone: report['zone'],
          started_at: Time.at(report['start']/1000),
          ended_at: Time.at(report['end']/1000),
        )
      end
    end

    redirect_to user_path(@user_id)
  end

  def show
    @reports = Report.where(user_id: @user_id).order(started_at: :desc)
  end

  private

  def get_user
    @user_id = params[:id] || params[:user_id]
  end
end
