# encoding: UTF-8

  
class ContractedHoursController < ApplicationController
  unloadable

  helper :sort
  include SortHelper
  helper :queries
  include QueriesHelper
  
  before_filter :build_new_contracted_hour, :only => [:new, :create]
  before_filter :find_contracted_hour, :only => [:edit, :update, :destroy]
  
  accept_rss_auth :index, :time_entries
  accept_api_auth :index, :show, :create, :update, :destroy, :time_entries
  #  redirect_to :back
  
  def index
    @contracted_hours = ContractedHour.find(:all, :order => 'id')
     
  end
  
  def show
  end
  
  def time_entries 
    @contracted_hour = ContractedHour.find params[:contracted_hour]
    @project = Project.find params[:project]
  end
 
  
  def export_csv
    @project = Project.find params[:project]
    @contracted_hour = ContractedHour.find params[:contracted_hour]
    issues= Issue.find params[:issues]
    respond_to do |format|
      format.html { send_data(statuses_to_csv(issues), :type => 'text/csv; header=present', :filename => 'spent_time.csv')  }
    end      
  end

  def statuses_to_csv (issues)
    encoding = l(:general_csv_encoding)
    export = FCSV.generate(:col_sep => l(:general_csv_separator)) do |csv|
      # csv header fields
      headers = [ 
        l(:label_issue),
        l(:label_project),
        l(:label_status),
        l(:label_tracker),
        l(:label_create),
        l(:label_description),
        l(:label_estimated_hours),
        l(:label_spent_time)
      ]
      #      csv << headers.collect {|c| begin; ic.iconv(c.to_s); rescue; c.to_s; end }
      csv << headers.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, encoding) }
      
      issues.each{|issue|
        # csv lines
        fields = [issue.id,
          Project.find(issue.project_id).name,
          IssueStatus.find(issue.status_id),
          Tracker.find(issue.tracker_id),
          issue.created_on,
          issue.subject,
          ContractedHour.new.clear_estimated_hour(issue),
          ContractedHour.new.month_time_entries(issue.id)
          ]
        csv << fields.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, encoding) }
      }
    end
    export
  end
  
  def edit
    @project = Project.find @contracted_hour.project_id
    @query = @contracted_hour
    @contracted_hours = ContractedHour.find(:all, :order => 'id')
  end

  def update
    @contracted_hour.build_from_params params
    if @contracted_hour.update_attributes params[:contracted_hour]
      flash[:notice] = l(:notice_successful_update)
      redirect_to contracted_hours_path
    else
      render :action => 'edit'
    end
  end
  
  def update_form
    @query = IssueQuery.new
    @query.user = User.current
    @query.project = Project.find params[:contracted_hour][:project_id]
    @query.visibility = IssueQuery::VISIBILITY_PRIVATE unless User.current.allowed_to?(:manage_public_queries, @project) || User.current.admin?
    @query.build_from_params(params)
  end
  
  def new
    @projects = Project.active.find(:all, :order => 'lft')
    @user = User.current
    @contracted_hours = ContractedHour.find(:all, :order => 'id')
    
    @query = IssueQuery.new
    @query.user = User.current
    @query.project = @project
    @query.visibility = IssueQuery::VISIBILITY_PRIVATE unless User.current.allowed_to?(:manage_public_queries, @project) || User.current.admin?
    @query.build_from_params(params)
  end
  
  def create
    save_contracted_hours params 
    flash[:notice] = l(:notice_successful_create)
    redirect_to :action => 'index'
  end
  
  def destroy
    @contracted_hour.destroy
    respond_to do |format|
      format.html { redirect_to(contracted_hours_path) }
      format.api  { render_api_ok }
    end
  end
  
  private
  
  def save_contracted_hours params
    
    @contracted_hour.project_id = params[:contracted_hour][:project_id]
    @contracted_hour.name = params[:contracted_hour][:name]
    @contracted_hour.hours = params[:contracted_hour][:hours]
    @contracted_hour.related_id = params[:contracted_hour][:related_id]
    @contracted_hour.build_from_params params
    @contracted_hour.save
  end

  def find_contracted_hour
    @contracted_hour = ContractedHour.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def build_new_contracted_hour
    @contracted_hour = ContractedHour.new
  end
  
end
