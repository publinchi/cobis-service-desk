class IssuesSidebarContractedHourHook < Redmine::Hook::ViewListener
  def view_issues_sidebar_queries_bottom(context = { })
    context[:controller].send(:render_to_string, {
        :partial => 'contracted_hours/view_issues_sidebar_queries_bottom',
        :locals => context })
  end
end

class ContractedHourHeaderHooks < Redmine::Hook::ViewListener
  include ApplicationHelper

  def view_layouts_base_html_head(context = {})
    o = stylesheet_link_tag('contracted_hours', :plugin => 'redmine_contracted_hours')
    return o
  end
end
