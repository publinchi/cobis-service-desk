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

class IssuesController < ApplicationController
  menu_item :new_issue, :only => [:new, :create]
  default_search_scope :issues

  before_filter :find_issue, :only => [:show, :edit, :update, :edit_extra, :update_extra]
  before_filter :find_issues, :only => [:bulk_edit, :bulk_update, :destroy]
  before_filter :find_project, :only => [:new, :create, :update_form, :update_assigned]
  before_filter :authorize, :except => [:index, :get_assignable_users, :get_assignable_users_extra, :required_watcher, :required_status_change, :not_permited, :edit_extra, :update_extra]
  before_filter :find_optional_project, :only => [:index]
  before_filter :check_for_default_issue_status, :only => [:new, :create]
  before_filter :build_new_issue_from_params, :only => [:new, :create, :update_form]
  accept_rss_auth :index, :show
  accept_api_auth :index, :show, :create, :update, :destroy, :update_extra

  rescue_from Query::StatementInvalid, :with => :query_statement_invalid

  helper :journals
  helper :projects
  include ProjectsHelper
  helper :custom_fields
  include CustomFieldsHelper
  helper :issue_relations
  include IssueRelationsHelper
  helper :watchers
  include WatchersHelper
  helper :attachments
  include AttachmentsHelper
  helper :queries
  include QueriesHelper
  helper :repositories
  include RepositoriesHelper
  helper :sort
  include SortHelper
  include IssuesHelper
  helper :timelog
  include Redmine::Export::PDF

  #funcion para calcular tiempo facturable por time_entrie
  def valor_estimated_hours(id)
    ActiveRecord::Base.connection.execute("select new_estimated_hours(#{id})")
  end
  
  def index
    retrieve_query
    sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
    sort_update(@query.sortable_columns)
    @query.sort_criteria = sort_criteria.to_a

    if @query.valid?
      case params[:format]
      when 'csv', 'pdf'
        @limit = Setting.issues_export_limit.to_i
        if params[:columns] == 'all'
          @query.column_names = @query.available_inline_columns.map(&:name)
        end
      when 'atom'
        @limit = Setting.feeds_limit.to_i
      when 'xml', 'json'
        @offset, @limit = api_offset_and_limit
        @query.column_names = %w(author)
      else
        @limit = per_page_option
      end

      @issue_count = @query.issue_count
      @issue_pages = Paginator.new @issue_count, @limit, params['page']
      @offset ||= @issue_pages.offset
      @issues = @query.issues(:include => [:assigned_to, :tracker, :priority, :category, :fixed_version],
        :order => sort_clause,
        :offset => @offset,
        :limit => @limit)
      @issue_count_by_group = @query.issue_count_by_group

      respond_to do |format|
        format.html { render :template => 'issues/index', :layout => !request.xhr? }
        format.api  {
          Issue.load_visible_relations(@issues) if include_in_api_response?('relations')
        }
        format.atom { render_feed(@issues, :title => "#{@project || Setting.app_title}: #{l(:label_issue_plural)}") }
        format.csv  { send_data(query_to_csv(@issues, @query, params), :type => 'text/csv; header=present', :filename => 'issues.csv') }
        format.pdf  { send_data(issues_to_pdf(@issues, @project, @query), :type => 'application/pdf', :filename => 'issues.pdf') }
      end
    else
      respond_to do |format|
        format.html { render(:template => 'issues/index', :layout => !request.xhr?) }
        format.any(:atom, :csv, :pdf) { render(:nothing => true) }
        format.api { render_validation_errors(@query) }
      end
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def otro(id)
    ActiveRecord::Base.connection.select_all("select i.id as \"caso\", p.identifier as \"proyecto\" from issues i join projects p on i.project_id=p.id where (i.project_id in (select id from projects where parent_id=10) and i.tracker_id=1) 
and i.closed_on > '2016-02-29 00:00:00' 
and i.status_id in (select id from issue_statuses where is_closed='t') 
and i.project_id in (
select id from projects where identifier in (select distinct(project_id) from polls) order by 1) 
and i.id not in (select distinct(issue_id) from poll_answers)
and i.is_private='f'
and i.author_id=#{id}
union
select i.id as \"caso\", p.identifier as \"proyecto\" from issues i join projects p on i.project_id=p.id where (i.project_id in (304,95,79,159,117) and i.tracker_id=6) 
and i.closed_on > '2016-02-29 00:00:00' 
and i.status_id in (select id from issue_statuses where is_closed='t') 
and i.project_id in (
select id from projects where identifier in (select distinct(project_id) from polls) order by 1) 
and i.id not in (select distinct(issue_id) from poll_answers)
and i.is_private='f'
and i.id in (select customized_id from custom_values where custom_field_id=64 and value='Mejora')
and i.author_id=#{id}
union
select i.id as \"caso\", p.identifier as \"proyecto\" from issues i join projects p on i.project_id=p.id where (i.project_id in (select id from projects where parent_id=105) and i.tracker_id=6) 
and i.closed_on > '2016-02-29 00:00:00' 
and i.status_id in (select id from issue_statuses where is_closed='t') 
and i.project_id in (
select id from projects where identifier in (select distinct(project_id) from polls) order by 1) 
and i.id not in (select distinct(issue_id) from poll_answers)
and i.is_private='f'
and i.author_id=#{id}")
  end
    
  def show
    @encuestas=[]
    @encuestas=otro(User.current.id) if User.current.client?
    @journals = @issue.journals.includes(:user, :details).reorder("#{Journal.table_name}.id ASC").all
    @journals.each_with_index {|j,i| j.indice = i+1}
    @journals.reject!(&:private_notes?) unless User.current.allowed_to?(:view_private_notes, @issue.project)
    Journal.preload_journals_details_custom_fields(@journals)
    # TODO: use #select! when ruby1.8 support is dropped
    @journals.reject! {|journal| !journal.notes? && journal.visible_details.empty?}
    @journals.reverse! if User.current.wants_comments_in_reverse_order?

    @changesets = @issue.changesets.visible.all
    @changesets.reverse! if User.current.wants_comments_in_reverse_order?

    @relations = @issue.relations.select {|r| r.other_issue(@issue) && r.other_issue(@issue).visible? }
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
    @edit_allowed = User.current.allowed_to?(:edit_issues, @project)
    @issue_status = IssueStatus.find(@issue.status_id)
    (!@issue_status.is_closed || (@issue_status.is_closed && User.current.allowed_to?(:edit_closed_issues, @project))) ? @validator_a = 1 : @validator_a = 0
    (!@issue_status.is_closed || (@issue_status.is_closed && User.current.allowed_to?(:add_issue_notes_to_closed_issues, @project))) ? @validator_b = 1 : @validator_b = 0
    @priorities = IssuePriority.active
    @time_entry = TimeEntry.new(:issue => @issue, :project => @issue.project)
    @relation = IssueRelation.new
    #Validar el uso de nuevo desarrollo de time entrie a nivel de proyecto
    @nuevo_desarrollo=CustomValue.find_by_customized_id_and_custom_field_id(@issue.project_id,129)
    
    respond_to do |format|
      format.html {
        retrieve_previous_and_next_issue_ids
        render :template => 'issues/show'
      }
      format.api
      format.atom { render :template => 'journals/index', :layout => false, :content_type => 'application/atom+xml' }
      format.pdf  {
        pdf = issue_to_pdf(@issue, :journals => @journals)
        send_data(pdf, :type => 'application/pdf', :filename => "#{@project.identifier}-#{@issue.id}.pdf")
      }
    end
  end

  # Add a new issue
  # The new issue will be created from an existing one if copy_from parameter is given
  def new
    @encuestas=[]
    @encuestas=otro(User.current.id) if User.current.client?
    respond_to do |format|
      format.html { render :action => 'new', :layout => !request.xhr? }
    end
  end

  def create
    @encuestas=[]
    @encuestas=otro(User.current.id) if User.current.client?
    call_hook(:controller_issues_new_before_save, { :params => params, :issue => @issue })
    @issue.save_attachments(params[:attachments] || (params[:issue] && params[:issue][:uploads]))
    if @issue.save
      call_hook(:controller_issues_new_after_save, { :params => params, :issue => @issue})
      respond_to do |format|
        format.html {
          render_attachment_warning_if_needed(@issue)
          flash[:notice] = l(:notice_issue_successful_create, :id => view_context.link_to("##{@issue.id}", issue_path(@issue), :title => @issue.subject))
          if params[:continue]
            attrs = {:tracker_id => @issue.tracker, :parent_issue_id => @issue.parent_issue_id}.reject {|k,v| v.nil?}
            redirect_to new_project_issue_path(@issue.project, :issue => attrs)
          else
            redirect_to issue_path(@issue)
          end
        }
        format.api  { render :action => 'show', :status => :created, :location => issue_url(@issue) }
      end
      return
    else
      respond_to do |format|
        format.html { render :action => 'new' }
        format.api  { render_validation_errors(@issue) }
      end
    end
  end

  def edit
    return unless update_issue_from_params
    #Validar el uso de nuevo desarrollo de time entrie a nivel de proyecto
    @nuevo_desarrollo=CustomValue.find_by_customized_id_and_custom_field_id(@issue.project_id,129)
    respond_to do |format|
      format.html { }
      format.xml  { }
    end
  end
  
  def edit_extra
    @valor_fecha = 1
    update_issue_from_params
    @journal = @issue.current_journal
    respond_to do |format|
      format.html { }
      format.xml  { }
    end
  end
  
  #funcion Actualizar sin fecha
  def update_extra
    @valor_fecha = 1
    @fecha_antes = fecha_issue(@issue.id)
    update
  end
 
  def update
    return unless update_issue_from_params
    @issue.save_attachments(params[:attachments] || (params[:issue] && params[:issue][:uploads]))
    saved = false
    begin
      saved = save_issue_with_child_records
    rescue ActiveRecord::StaleObjectError
      @conflict = true
      if params[:last_journal_id]
        @conflict_journals = @issue.journals_after(params[:last_journal_id]).all
        @conflict_journals.reject!(&:private_notes?) unless User.current.allowed_to?(:view_private_notes, @issue.project)
      end
    end

    if saved
      fecha_actualizacion(@issue.id, @fecha_antes) if @valor_fecha.to_s=='1'
      valor_estimated_hours(@issue.id) if @issue.tracker_id.to_s!='2'
      render_attachment_warning_if_needed(@issue)
      flash[:notice] = l(:notice_successful_update) unless @issue.current_journal.new_record?

      respond_to do |format|
        format.html { redirect_back_or_default issue_path(@issue) }
        format.api  { render_api_ok }
      end
    else
      #Validar el uso de nuevo desarrollo de time entrie a nivel de proyecto
      @nuevo_desarrollo=CustomValue.find_by_customized_id_and_custom_field_id(@issue.project_id,129)
      respond_to do |format|
        format.html { render :action => 'edit' }
        format.api  { render_validation_errors(@issue) }
      end
    end
  end

  # Updates the issue form when changing the project, status or tracker
  # on issue creation/update
  def update_form
  end

  # Bulk edit/copy a set of issues
  def bulk_edit
    @issues.sort!
    @copy = params[:copy].present?
    @notes = params[:notes]

    if User.current.allowed_to?(:move_issues, @projects)
      @allowed_projects = Issue.allowed_target_projects_on_move
      if params[:issue]
        @target_project = @allowed_projects.detect {|p| p.id.to_s == params[:issue][:project_id].to_s}
        if @target_project
          target_projects = [@target_project]
        end
      end
    end
    target_projects ||= @projects

    if @copy
      @available_statuses = [IssueStatus.default]
    else
      @available_statuses = @issues.map(&:new_statuses_allowed_to).reduce(:&)
    end
    @custom_fields = target_projects.map{|p|p.all_issue_custom_fields.visible}.reduce(:&)
    @assignables = target_projects.map(&:assignable_users).reduce(:&)
    @trackers = target_projects.map(&:trackers).reduce(:&)
    @versions = target_projects.map {|p| p.shared_versions.open}.reduce(:&)
    @categories = target_projects.map {|p| p.issue_categories}.reduce(:&)
    if @copy
      @attachments_present = @issues.detect {|i| i.attachments.any?}.present?
      @subtasks_present = @issues.detect {|i| !i.leaf?}.present?
    end

    @safe_attributes = @issues.map(&:safe_attribute_names).reduce(:&)

    @issue_params = params[:issue] || {}
    @issue_params[:custom_field_values] ||= {}
  end

  def bulk_update
    @issues.sort!
    @copy = params[:copy].present?
    attributes = parse_params_for_bulk_issue_attributes(params)

    unsaved_issues = []
    saved_issues = []

    if @copy && params[:copy_subtasks].present?
      # Descendant issues will be copied with the parent task
      # Don't copy them twice
      @issues.reject! {|issue| @issues.detect {|other| issue.is_descendant_of?(other)}}
    end

    @issues.each do |orig_issue|
      orig_issue.reload
      if @copy
        issue = orig_issue.copy({},
          :attachments => params[:copy_attachments].present?,
          :subtasks => params[:copy_subtasks].present?
        )
      else
        issue = orig_issue
      end
      journal = issue.init_journal(User.current, params[:notes])
      issue.safe_attributes = attributes
      call_hook(:controller_issues_bulk_edit_before_save, { :params => params, :issue => issue })
      if issue.save
        saved_issues << issue
      else
        unsaved_issues << orig_issue
      end
    end

    if unsaved_issues.empty?
      flash[:notice] = l(:notice_successful_update) unless saved_issues.empty?
      if params[:follow]
        if @issues.size == 1 && saved_issues.size == 1
          redirect_to issue_path(saved_issues.first)
        elsif saved_issues.map(&:project).uniq.size == 1
          redirect_to project_issues_path(saved_issues.map(&:project).first)
        end
      else
        redirect_back_or_default _project_issues_path(@project)
      end
    else
      @saved_issues = @issues
      @unsaved_issues = unsaved_issues
      @issues = Issue.visible.where(:id => @unsaved_issues.map(&:id)).all
      bulk_edit
      render :action => 'bulk_edit'
    end
  end

  def destroy
    @hours = TimeEntry.where(:issue_id => @issues.map(&:id)).sum(:hours).to_f
    if @hours > 0
      case params[:todo]
      when 'destroy'
        # nothing to do
      when 'nullify'
        TimeEntry.where(['issue_id IN (?)', @issues]).update_all('issue_id = NULL')
      when 'reassign'
        reassign_to = @project.issues.find_by_id(params[:reassign_to_id])
        if reassign_to.nil?
          flash.now[:error] = l(:error_issue_not_found_in_project)
          return
        else
          TimeEntry.where(['issue_id IN (?)', @issues]).
            update_all("issue_id = #{reassign_to.id}")
        end
      else
        # display the destroy form if it's a user request
        return unless api_request?
      end
    end
    @issues.each do |issue|
      begin
        issue.reload.destroy
      rescue ::ActiveRecord::RecordNotFound # raised by #reload if issue no longer exists
        # nothing to do, issue was already deleted (eg. by a parent)
      end
    end
    respond_to do |format|
      format.html { redirect_back_or_default _project_issues_path(@project) }
      format.api  { render_api_ok }
    end
  end

  def get_assignable_users
    issue = Issue.find(params[:issue_id])
    
    members = Member.find(:all, :conditions => ["project_id=?", issue.project_id], :select => "DISTINCT(id)")

    member_roles = MemberRole.find(:all, :conditions => ["member_id IN (?)", members.map(&:id).uniq], :select => "DISTINCT(role_id)")
    member_roles_tmp = []
    member_roles.each { |mr|      
      role = Role.find(mr.role_id)
      if role.assignable == true
        member_roles_tmp << mr.role_id
      end 
    }
    
    workflows = Workflow.find(:all, :conditions => ["tracker_id=? and old_status_id=? and role_id IN (?)", params[:tipo_id], params[:issue][:status_id], member_roles_tmp.uniq], :select => "role_id")
    
    member_roles = MemberRole.find(:all, :conditions => ["role_id IN (?)", workflows.map(&:role_id).uniq], :select => "member_id")
    
    members = Member.find(:all, :conditions => ["id IN (?) and project_id=?", member_roles.map(&:member_id).uniq, issue.project_id], :select => "user_id")
    
    @users = User.find(:all, :order => "firstname ASC",:conditions => ["id IN (?) and status!=?" , members.map(&:user_id).uniq, 3])

    (add_group_to_user_list @users) if Setting.issue_group_assignment?
    
    return render(:partial => 'issues/get_assignable_users', :layout => false) if request.xhr?
  end

  def get_assignable_users_extra
    members = Member.find(:all, :conditions => ["project_id=?", params[:project_id]], :select => "DISTINCT(id)")

    member_roles = MemberRole.find(:all, :conditions => ["member_id IN (?)", members.map(&:id).uniq], :select => "DISTINCT(role_id)")
    member_roles_tmp = []
    member_roles.each { |mr|      
      role = Role.find(mr.role_id)
      if role.assignable == true
        member_roles_tmp << mr.role_id
      end 
    }

    workflows = Workflow.find(:all, :conditions => ["tracker_id=? and old_status_id=? and role_id IN (?)", params[:tipo_id], params[:status_id], member_roles_tmp.uniq], :select => "role_id")
    
    member_roles = MemberRole.find(:all, :conditions => ["role_id IN (?)", workflows.map(&:role_id).uniq], :select => "member_id")
    
    members = Member.find(:all, :conditions => ["id IN (?) and project_id=?", member_roles.map(&:member_id).uniq, params[:project_id]], :select => "user_id")
    
    @users = User.find(:all, :order => "firstname ASC", :conditions => ["id IN (?) and status!=?" , members.map(&:user_id).uniq, 3])
    
    add_group_to_user_list @users if Setting.issue_group_assignment?
    
    return render(:partial => 'issues/get_assignable_users', :layout => false) if request.xhr?
  end
  
  # Renderiza un botón (_button_submit.rhtml) dependiendo de las validaciones (valida con el nuevo estado seleccionado del combo)
  def required_watcher
    issue_status = IssueStatus.find(params[:issue_status_id])
    watchers =Watcher.find(:all, :conditions => ["watchable_id=?", params[:issue_id]]) 
    @issue_status1 = IssueStatus.find_by_id(params[:issue_status_id1])
    @project1 = Project.find_by_id(params[:project_id1]) 
    @issue1 = Issue.find_by_id(params[:issue_id])
    @submit = 1 if (issue_status.is_watcher_required == true && watchers.length > 0)
    @submit = 2 if (issue_status.is_watcher_required == true && watchers.length == 0)
    @submit = 3 if (issue_status.is_watcher_required == false || issue_status.is_watcher_required.nil?)
    return render(:partial => 'issues/button_submit', :layout => false) if request.xhr?
  end 
  
  # Renderiza un botón (_button_submit.rhtml) dependiendo de las validaciones (valida si el estado debe ser cambiado o no)
  def required_status_change
    issue_status = IssueStatus.find(params[:issue][:status_id])
    issue = Issue.find(params[:issue_id])
    @issue_status1 = IssueStatus.find_by_id(params[:issue_status_id1])
    @project1 = Project.find_by_id(params[:project_id1])
    @issue1 = Issue.find_by_id(params[:issue_id])
    if issue_status.id != issue.status_id
      @submit=1
    elsif issue_status.id == issue.status_id
      (User.current.id == issue.author_id || User.current.client == true) ? @submit=4 : @submit=1
    end
    return render(:partial => 'issues/button_submit', :layout => false) if request.xhr?
  end

  private

  def find_project
    project_id = params[:project_id] || (params[:issue] && params[:issue][:project_id])
    @project = Project.find(project_id)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def retrieve_previous_and_next_issue_ids
    retrieve_query_from_session
    if @query
      sort_init(@query.sort_criteria.empty? ? [['id', 'desc']] : @query.sort_criteria)
      sort_update(@query.sortable_columns, 'issues_index_sort')
      limit = 500
      issue_ids = @query.issue_ids(:order => sort_clause, :limit => (limit + 1), :include => [:assigned_to, :tracker, :priority, :category, :fixed_version])
      if (idx = issue_ids.index(@issue.id)) && idx < limit
        if issue_ids.size < 500
          @issue_position = idx + 1
          @issue_count = issue_ids.size
        end
        @prev_issue_id = issue_ids[idx - 1] if idx > 0
        @next_issue_id = issue_ids[idx + 1] if idx < (issue_ids.size - 1)
      end
    end
  end

  # Used by #edit and #update to set some common instance variables
  # from the params
  # TODO: Refactor, not everything in here is needed by #edit
  def update_issue_from_params
    @edit_allowed = User.current.allowed_to?(:edit_issues, @project)
    @time_entry = TimeEntry.new(:issue => @issue, :project => @issue.project)
    @time_entry.attributes = params[:time_entry]

    @issue.init_journal(User.current)

    issue_attributes = params[:issue]
    if issue_attributes && params[:conflict_resolution]
      case params[:conflict_resolution]
      when 'overwrite'
        issue_attributes = issue_attributes.dup
        issue_attributes.delete(:lock_version)
      when 'add_notes'
        issue_attributes = issue_attributes.slice(:notes)
      when 'cancel'
        redirect_to issue_path(@issue)
        return false
      end
    end
    @issue.safe_attributes = issue_attributes
    @priorities = IssuePriority.active
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current)
    true
  end

  # TODO: Refactor, lots of extra code in here
  # TODO: Changing tracker on an existing issue should not trigger this
  def build_new_issue_from_params
    if params[:id].blank?
      @issue = Issue.new
      if params[:copy_from]
        begin
          @copy_from = Issue.visible.find(params[:copy_from])
          @copy_attachments = params[:copy_attachments].present? || request.get?
          @copy_subtasks = params[:copy_subtasks].present? || request.get?
          @issue.copy_from(@copy_from, :attachments => @copy_attachments, :subtasks => @copy_subtasks)
        rescue ActiveRecord::RecordNotFound
          render_404
          return
        end
      end
      @issue.project = @project
    else
      @issue = @project.issues.visible.find(params[:id])
    end

    @issue.project = @project
    @issue.author ||= User.current
    # Tracker must be set before custom field values
    @issue.tracker ||= @project.trackers.find((params[:issue] && params[:issue][:tracker_id]) || params[:tracker_id] || :first)
    if @issue.tracker.nil?
      render_error l(:error_no_tracker_in_project)
      return false
    end
    @issue.start_date ||= Date.today if Setting.default_issue_start_date_to_creation_date?
    @issue.safe_attributes = params[:issue]

    @priorities = IssuePriority.active
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current, @issue.new_record?)
    @available_watchers = @issue.watcher_users
    if @issue.project.users.count <= 20
      @available_watchers = (@available_watchers + @issue.project.users.sort).uniq
    end
  end

  def check_for_default_issue_status
    if IssueStatus.default.nil?
      render_error l(:error_no_default_issue_status)
      return false
    end
  end

  def parse_params_for_bulk_issue_attributes(params)
    attributes = (params[:issue] || {}).reject {|k,v| v.blank?}
    attributes.keys.each {|k| attributes[k] = '' if attributes[k] == 'none'}
    if custom = attributes[:custom_field_values]
      custom.reject! {|k,v| v.blank?}
      custom.keys.each do |k|
        if custom[k].is_a?(Array)
          custom[k] << '' if custom[k].delete('__none__')
        else
          custom[k] = '' if custom[k] == '__none__'
        end
      end
    end
    attributes
  end

  # Saves @issue and a time_entry from the parameters
  def save_issue_with_child_records
    Issue.transaction do
      if @issue.route_id.blank?
      elsif (@issue.author_id == User.current.id || User.current.client == true) && @issue.tracker_id != 5
        @project = Project.find @issue.project_id
        if @project.parent_id == 10 || @project.parent_id == 103
          case @issue.status_id
          when 5, 11, 12, 24, 27, 31, 46
            @issue.assigned_to_id = @issue.route_id
          end
        else
          @issue.assigned_to_id = @issue.route_id
        end
      end
      
      if params[:time_entry] && User.current.client != true && !params[:time_entry][:hours].present?
        params[:time_entry][:hours]=0
      end
      
      if params[:time_entry] && (params[:time_entry][:hours].present? || params[:time_entry][:comments].present?) && User.current.allowed_to?(:log_time, @issue.project)
        time_entry = @time_entry || TimeEntry.new
        time_entry.project = @issue.project
        time_entry.issue = @issue
        time_entry.user = User.current
        time_entry.spent_on = User.current.today
        time_entry.attributes = params[:time_entry]
        @issue.time_entries << time_entry
      end
      
      call_hook(:controller_issues_edit_before_save, { :params => params, :issue => @issue, :time_entry => time_entry, :journal => @issue.current_journal})
      if @issue.save
        call_hook(:controller_issues_edit_after_save, { :params => params, :issue => @issue, :time_entry => time_entry, :journal => @issue.current_journal})
      else
        raise ActiveRecord::Rollback
      end
    end
  end
  
  #funciones para cambios sin modificar fecha
  def fecha_actualizacion(id,fecha)
    ActiveRecord::Base.connection.execute("update issues set updated_on='#{fecha}' where id=#{id}")
  end
  
  def fecha_issue(id)
    ActiveRecord::Base.connection.select_value("select updated_on from issues where id=#{id}")
  end
  
  def add_group_to_user_list users
    users_temp = @project.assignable_users
    users_temp.each {|ut|
      (users << ut) if ut.is_a?(Group) && ut.status!=3
    }
  end
  
end
