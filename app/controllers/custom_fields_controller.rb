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

class CustomFieldsController < ApplicationController
  layout 'admin'

  before_filter :require_admin
  before_filter :build_new_custom_field, :only => [:new, :create]
  before_filter :find_custom_field, :only => [:edit, :update, :destroy]
  accept_api_auth :index

  def index
    respond_to do |format|
      format.html {
        @custom_fields_by_type = CustomField.all.group_by {|f| f.class.name }
      }
      format.api {
        @custom_fields = CustomField.all
      }
    end
  end

  def new
    @custom_field.field_format = 'string' if @custom_field.field_format.blank?
    @custom_field.default_value = nil
  end

  def create
    if @custom_field.save
      flash[:notice] = l(:notice_successful_create)
      call_hook(:controller_custom_fields_new_after_save, :params => params, :custom_field => @custom_field)
      redirect_to custom_fields_path(:tab => @custom_field.class.name)
    else
      render :action => 'new'
    end
  end

  def edit
  end

  def update
    if @custom_field.update_attributes(params[:custom_field])
      
      save_custom_fields CustomFieldsUpdateRoles, @custom_field.id, params[:check]
      save_custom_fields CustomFieldsInsertRoles, @custom_field.id, params[:check1]
      save_custom_fields_statuses CustomFieldsStatuses, @custom_field.id,params[:check2]
      
      flash[:notice] = l(:notice_successful_update)
      call_hook(:controller_custom_fields_edit_after_save, :params => params, :custom_field => @custom_field)
      redirect_to custom_fields_path(:tab => @custom_field.class.name)
    else
      render :action => 'edit'
    end
  end

  def destroy
    begin
      @custom_field.destroy
    rescue
      flash[:error] = l(:error_can_not_delete_custom_field)
    end
    redirect_to custom_fields_path(:tab => @custom_field.class.name)
  end

  private

  def build_new_custom_field
    @custom_field = CustomField.new_subclass_instance(params[:type], params[:custom_field])
    if @custom_field.nil?
      render :action => 'select_type'
    end
  end

  def find_custom_field
    @custom_field = CustomField.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  # Saves custom_field_update and custom_field_insert -> mgraqnja, pestupinan
  def save_custom_fields object, custom_field_id, parameters
    cfs = object.find_all_by_custom_field_id(@custom_field.id)
    cfs.each { |item| item.delete }
    if parameters != nil
      parameters.each do |param|
        cf = object.new
        cf.role_id = param
        cf.custom_field_id = custom_field_id
        cf.save
      end
    end
  end

  def save_custom_fields_statuses object, custom_field_id, parameters
    cfs = object.find_all_by_custom_field_id(@custom_field.id)
    cfs.each { |item| item.delete}
    if parameters != nil
      parameters.each do |param|
        cf = object.new
        cf.issue_status_id = param
        cf.custom_field_id = custom_field_id
        cf.is_required=1   
        cf.save
      end
    end
  end
  
end
