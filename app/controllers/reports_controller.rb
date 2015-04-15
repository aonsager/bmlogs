class ReportsController < ApplicationController
  before_filter :get_report

  def import
    response = HTTParty.get("https://www.warcraftlogs.com:443/v1/report/fights/#{@report_id}?api_key=#{ENV['API_KEY']}")
    obj = JSON.parse(response.body)
    fights = obj['fights']
    players = obj['friendlies']
    fights.each do |fight|
      next if fight['boss'].to_i == 0
      if !Fight.exists?(report_id: @report_id, fight_id: fight['id'])
        Fight.create(
          report_id: @report_id,
          fight_id: fight['id'],
          name: fight['name'],
          boss_id: fight['boss'],
          size: fight['size'],
          difficulty: fight['difficulty'],
          kill: fight['kill'],
          started_at: fight['start_time'],
          ended_at: fight['end_time'],
        )
      end
    end

    report = Report.where(report_id: @report_id).first
    report.update_attribute(:imported, true)

    redirect_to user_path(report.user_id)
  end

  def show
    @report = Report.where(report_id: @report_id).first
    @fights = Fight.where(report_id: @report_id).order(fight_id: :asc)
  end

  private

  def get_report
    @report_id = params[:report_id] || params[:id]
  end
end
