crumb :root do
  link "Home", root_path
end

crumb :user_report do |user_id|
  link "#{user_id} - Reports", user_path(user_id)
end

crumb :user_chars do |user_id|
  link "#{user_id} - Characters", user_players_path(user_id)
end

crumb :report do |report|
  link report.title, report_path(report.report_id)
  parent :user_report, report.user_id
end

crumb :fight do |fight, fp, report|
  link "#{fight.name} (#{fp.fight_time / 60}:#{fp.fight_time % 60})", fight_path(fight.id)
  parent :report, report
end

crumb :player do |player_id, player_name|
  link player_name, player_path(player_id)
  parent :user_chars, session[:user_id]
end

crumb :boss do |boss_id, boss_name, player_id, player_name|
  link boss_name, player_boss_path(player_id, boss_id)
  parent :player, player_id, player_name
end

# crumb :projects do
#   link "Projects", projects_path
# end

# crumb :project do |project|
#   link project.name, project_path(project)
#   parent :projects
# end

# crumb :project_issues do |project|
#   link "Issues", project_issues_path(project)
#   parent :project, project
# end

# crumb :issue do |issue|
#   link issue.title, issue_path(issue)
#   parent :project_issues, issue.project
# end

# If you want to split your breadcrumbs configuration over multiple files, you
# can create a folder named `config/breadcrumbs` and put your configuration
# files there. All *.rb files (e.g. `frontend.rb` or `products.rb`) in that
# folder are loaded and reloaded automatically when you change them, just like
# this file (`config/breadcrumbs.rb`).