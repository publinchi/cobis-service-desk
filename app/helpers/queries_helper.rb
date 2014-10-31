# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2014  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

module QueriesHelper
  def filters_options_for_select(query)
    options_for_select(filters_options(query))
  end

  def filters_options(query)
    if @project.nil? && !User.current.members.first.nil?
      user = User.current 
      project = user.members.first.project
    end
    if !User.current.members.first.nil? 
      permissions = allowed_to_permissions @project 
      filter = query.available_filters 
      current_user_allowed_to_filter?("assigned_to_id", filter, permissions[:assigned_to]) 
      current_user_allowed_to_filter?("priority_id", filter, permissions[:priority]) 
      current_user_allowed_to_filter?("category_id", filter, permissions[:category]) 
      current_user_allowed_to_filter?("estimated_hours", filter, permissions[:estimated_hours]) 
      current_user_allowed_to_filter?("done_ratio", filter, permissions[:done_ratio]) 
      current_user_allowed_to_filter?("due_date", filter, permissions[:due_date]) 
      current_user_allowed_to_filter?("status_id", filter, permissions[:status]) 
      current_user_allowed_to_filter?("route_id", filter, permissions[:view_responsable]) 
      current_user_allowed_to_filter?("is_private", filter, user_allowed_to_view_private_issues?(User.current.id, @project))
    else 
      filter = query.available_filters
    end 
    options = [[]]
    options += filter.map do |field, field_options|
      [field_options[:name], field]
    end
  end

  def query_filters_hidden_tags(query)
    tags = ''.html_safe
    query.filters.each do |field, options|
      tags << hidden_field_tag("f[]", field, :id => nil)
      tags << hidden_field_tag("op[#{field}]", options[:operator], :id => nil)
      options[:values].each do |value|
        tags << hidden_field_tag("v[#{field}][]", value, :id => nil)
      end
    end
    tags
  end

  def query_columns_hidden_tags(query)
    tags = ''.html_safe
    query.columns.each do |column|
      tags << hidden_field_tag("c[]", column.name, :id => nil)
    end
    tags
  end

  def query_hidden_tags(query)
    query_filters_hidden_tags(query) + query_columns_hidden_tags(query)
  end

  def available_block_columns_tags(query)
    tags = ''.html_safe
    query.available_block_columns.each do |column|
      tags << content_tag('label', check_box_tag('c[]', column.name.to_s, query.has_column?(column), :id => nil) + " #{column.caption}", :class => 'inline')
    end
    tags
  end

  def query_available_inline_columns_options(query)
    permissions = allowed_to_permissions @project
    columns = query.available_inline_columns - query.columns
    current_user_allowed_to?(:due_date, columns, permissions[:due_date]) 
    current_user_allowed_to?(:category, columns, permissions[:category]) 
    current_user_allowed_to?(:start_date, columns, permissions[:start_date]) 
    current_user_allowed_to?(:status, columns, permissions[:status]) 
    current_user_allowed_to?(:estimated_hours, columns, permissions[:estimated_hours]) 
    current_user_allowed_to?(:done_ratio, columns, permissions[:done_ratio]) 
    current_user_allowed_to?(:priority, columns, permissions[:priority]) 
    current_user_allowed_to?(:assigned_to, columns, permissions[:assigned_to]) 
    current_user_allowed_to?(:view_responsable, columns, permissions[:view_responsable]) 
    current_user_allowed_to?(:is_private, columns, user_allowed_to_view_private_issues?(User.current.id, @project)) 
    if User.current.client==true
      columns.delete_if {|column| column.name.to_s=='priority'} 
    else
      if !@project.blank?
        @cf=CustomField.find_by_id(62)
        if @project.all_issue_custom_fields.include? (@cf) 
          columns.delete_if {|column| column.name.to_s=='cf_62'} 
        end
      end
    end
    columns.reject(&:frozen?).collect {|column| [column.caption, column.name]}
  end

  def query_selected_inline_columns_options(query)
    permissions = allowed_to_permissions @project
    columns = query.columns 
    @valor_index=columns.index { |x| x.name.to_s == "priority" }
    @valor_index_cf=columns.index { |x| x.name.to_s == "cf_62" }
    if User.current.client==true and @valor_index.blank?
      columns.insert(3,QueryColumn.new(:priority, :sortable => "#{IssuePriority.table_name}.position", :default_order => 'desc', :groupable => true))
    end
    if User.current.client==false and @valor_index_cf.blank?
      if !@project.blank?
        @cf=CustomField.find_by_id(62)
        if @project.all_issue_custom_fields.include? (@cf)
          columns.insert(3,QueryCustomFieldColumn.new(@cf))
          columns.delete_if {|column| column.name.to_s=='priority'} 
        end
      end
    end
    
    current_user_allowed_to?(:due_date, columns, permissions[:due_date])
    current_user_allowed_to?(:category, columns, permissions[:category]) 
    current_user_allowed_to?(:start_date, columns, permissions[:start_date]) 
    current_user_allowed_to?(:status, columns, permissions[:status]) 
    current_user_allowed_to?(:estimated_hours, columns, permissions[:estimated_hours]) 
    current_user_allowed_to?(:done_ratio, columns, permissions[:done_ratio]) 
    current_user_allowed_to?(:priority, columns, permissions[:priority]) 
    current_user_allowed_to?(:assigned_to, columns, permissions[:assigned_to]) 
    current_user_allowed_to?(:view_responsable, columns, permissions[:view_responsable]) 
    current_user_allowed_to?(:is_private, columns, user_allowed_to_view_private_issues?(User.current.id, @project)) 
    columns.reject(&:frozen?).collect {|column| [column.caption, column.name]}
  end

  def render_query_columns_selection(query, options={})
    tag_name = (options[:name] || 'c') + '[]'
    render :partial => 'queries/columns', :locals => {:query => query, :tag_name => tag_name}
  end

  def column_header(column)
    column.sortable ? sort_header_tag(column.name.to_s, :caption => column.caption,
      :default_order => column.default_order) :
      content_tag('th', h(column.caption))
  end

  def column_content(column, issue)
    value = column.value(issue)
    if value.is_a?(Array)
      value.collect {|v| column_value(column, issue, v)}.compact.join(', ').html_safe
    else
      column_value(column, issue, value)
    end
  end
  
  def column_value(column, issue, value)
    case column.name
    when :id
      link_to value, issue_path(issue)
    when :subject
      link_to value, issue_path(issue)
    when :description
      issue.description? ? content_tag('div', textilizable(issue, :description), :class => "wiki") : ''
    when :done_ratio
      progress_bar(value, :width => '80px')
    when :relations
      other = value.other_issue(issue)
      content_tag('span',
        (l(value.label_for(issue)) + " " + link_to_issue(other, :subject => false, :tracker => false)).html_safe,
        :class => value.css_classes_for(issue))
    when :route_id
      @user=User.find_by_id(value)
      link_to_user @user
    else
      format_object(value)
    end
  end

  def csv_content(column, issue)
    value = column.value(issue)
    if value.is_a?(Array)
      value.collect {|v| csv_value(column, issue, v)}.compact.join(', ')
    else
      csv_value(column, issue, value)
    end
  end

  def csv_value(column, issue, value)
    case value.class.name
    when 'Time'
      format_time(value)
    when 'Date'
      format_date(value)
    when 'Float'
      sprintf("%.2f", value).gsub('.', l(:general_csv_decimal_separator))
    when 'IssueRelation'
      other = value.other_issue(issue)
      l(value.label_for(issue)) + " ##{other.id}"
    when 'TrueClass'
      l(:general_text_Yes)
    when 'FalseClass'
      l(:general_text_No)
    when 'Fixnum'
      case column.name
      when :route_id
        @value = User.find_by_id(value)
        value = @value.to_s
      else
        value.to_s
      end
    else     
      value.to_s
    end
  end
  
  def query_to_csv(items, query, options={})
    encoding = l(:general_csv_encoding)
    columns = (options[:columns] == 'all' ? query.available_inline_columns : query.inline_columns)
    query.available_block_columns.each do |column|
      if options[column.name].present?
        columns << column
      end
    end

    export = FCSV.generate(:col_sep => l(:general_csv_separator)) do |csv|
      # csv header fields
      csv << columns.collect {|c| Redmine::CodesetUtil.from_utf8(c.caption.to_s, encoding) }
      # csv lines
      items.each do |item|
        csv << columns.collect {|c| Redmine::CodesetUtil.from_utf8(csv_content(c, item), encoding) }
      end
    end
    export
  end

  # Retrieve query from session or build a new query
  def retrieve_query
    if !params[:query_id].blank?
      cond = "project_id IS NULL"
      cond << " OR project_id = #{@project.id}" if @project
      @query = IssueQuery.where(cond).find(params[:query_id])
      raise ::Unauthorized unless @query.visible?
      @query.project = @project
      session[:query] = {:id => @query.id, :project_id => @query.project_id}
      sort_clear
    elsif api_request? || params[:set_filter] || session[:query].nil? || session[:query][:project_id] != (@project ? @project.id : nil)
      # Give it a name, required to be valid
      @query = IssueQuery.new(:name => "_")
      @query.project = @project
      @query.build_from_params(params)
      session[:query] = {:project_id => @query.project_id, :filters => @query.filters, :group_by => @query.group_by, :column_names => @query.column_names}
    else
      # retrieve from session
      @query = nil
      @query = IssueQuery.find_by_id(session[:query][:id]) if session[:query][:id]
      @query ||= IssueQuery.new(:name => "_", :filters => session[:query][:filters], :group_by => session[:query][:group_by], :column_names => session[:query][:column_names])
      @query.project = @project
    end
  end

  def retrieve_query_from_session
    if session[:query]
      if session[:query][:id]
        @query = IssueQuery.find_by_id(session[:query][:id])
        return unless @query
      else
        @query = IssueQuery.new(:name => "_", :filters => session[:query][:filters], :group_by => session[:query][:group_by], :column_names => session[:query][:column_names])
      end
      if session[:query].has_key?(:project_id)
        @query.project_id = session[:query][:project_id]
      else
        @query.project = @project
      end
      @query
    end
  end
  
  def allowed_to_permissions project
    @permissions = Hash.new

    @permissions[:due_date] = User.current.allowed_to?(:due_date, project)
    @permissions[:category] = User.current.allowed_to?(:category, project)
    @permissions[:start_date] = User.current.allowed_to?(:start_date, project)
    @permissions[:status] = User.current.allowed_to?(:status, project)
    @permissions[:estimated_hours] = User.current.allowed_to?(:estimated_hours, project)
    @permissions[:done_ratio] = User.current.allowed_to?(:done_ratio, project)
    @permissions[:priority] = User.current.allowed_to?(:priority, project)
    @permissions[:assigned_to] = User.current.allowed_to?(:assigned_to, project)
    @permissions[:view_responsable] = User.current.allowed_to?(:view_responsable, project)
    @permissions[:view_time_entries] = User.current.allowed_to?(:view_time_entries, project)

    @permissions
  end

  def current_user_allowed_to_filter? permission, filters, bool
    filters.each  do |key,value|
      filters.delete(key){ puts "Filtro no encontrado: #{key}" } if key==permission && !bool
    end
  end

  def user_allowed_to_view_private_issues? user, project
    permission_private=false
    member = Member.find_by_user_id_and_project_id(user, project)
    member_roles = MemberRole.find_all_by_member_id(member)
    member_roles.each do |memberRole|
      rol = Role.find_by_id(memberRole.role_id)
      permission_private = true if rol.issues_visibility == "all"
    end
    permission_private
  end

  def current_user_allowed_to? permission, columns, bool
    columns.each  do |a|
      columns.delete(a){ puts "Columna no encontrada: #{a.name}" } if a.name == permission && !bool
    end
  end
end
