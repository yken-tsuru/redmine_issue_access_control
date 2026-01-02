class IssueAccessRule < ActiveRecord::Base
  belongs_to :issue
  belongs_to :principal, class_name: 'Principal'

  validates_presence_of :issue, :principal
  validates_uniqueness_of :principal_id, scope: :issue_id
end
