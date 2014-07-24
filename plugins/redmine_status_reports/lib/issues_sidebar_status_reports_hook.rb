# Provides a link to the issue age graph on the issue index page
class IssuesSidebarStatusReportsHook < Redmine::Hook::ViewListener
  def view_issues_sidebar_issues_bottom(context = { })
    context[:controller].send(:render_to_string, {
      :partial => 'status_reports/view_issues_sidebar_issues_bottom',
      :locals => context })
  end
end
