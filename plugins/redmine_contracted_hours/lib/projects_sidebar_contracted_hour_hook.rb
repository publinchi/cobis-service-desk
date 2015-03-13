class ProjectsSidebarContractedHourHook < Redmine::Hook::ViewListener
  def view_projects_show_sidebar_bottom(context = { })
    context[:controller].send(:render_to_string, {
        :partial => 'contracted_hours/view_projects_sidebar_issues_bottom',
        :locals => context })
  end
end
