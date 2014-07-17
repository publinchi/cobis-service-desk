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

module IssueStatusesHelper
  
  def by_stado_required_estado(id,custom_field)
    ActiveRecord::Base.connection.select_value("select is_required from custom_fields_statuses where issue_status_id=#{id} and custom_field_id=#{custom_field}")
  end
  
  def allowed_custom_status_estado?(id,custom_field_id)
    @llenado=by_stado_required_estado(id,custom_field_id)   
    per1=nil
    if @llenado.to_s=='1'
      per1=true
    else
      per1=false
    end
    per1
  end
  
end
