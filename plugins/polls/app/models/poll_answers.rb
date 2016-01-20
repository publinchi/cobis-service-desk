class PollAnswers < ActiveRecord::Base
    belongs_to :poll
    belongs_to :user
    belongs_to :answer
    belongs_to :issue
end
