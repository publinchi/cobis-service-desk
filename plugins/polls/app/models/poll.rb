class Poll < ActiveRecord::Base
  has_many :answers
  
   extend ActiveModel::Naming

  def initialize
    @errors = ActiveModel::Errors.new(self)
  end

  attr_accessor :poll_id
  attr_reader   :errors
  
  def validate!
    if @poll.mandatory == true
      errors.add(:poll_id, "No")
    end
  end
  
  
#  def validate!
#    errors.add(:name, "cannot be nil") if name.nil?
#  end
  
  
end
