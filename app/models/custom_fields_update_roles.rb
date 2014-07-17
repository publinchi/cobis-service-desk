class CustomFieldsUpdateRoles < ActiveRecord::Base

  has_many :roles, :foreign_key => "role_id"
  has_many :custom_fields, :foreign_key => "custom_field_id"

end
