class CustomFieldsStatuses < ActiveRecord::Base

  has_many :issue_statuses, :foreign_key => "issue_status_id"
  has_many :custom_fields, :foreign_key => "custom_field_id"
  
end
