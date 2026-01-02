class IssueAccessRule < ActiveRecord::Base
  # Associations
  belongs_to :issue
  belongs_to :principal, class_name: 'Principal'

  # Validations
  validates :issue, presence: true
  validates :principal, presence: true
  validates :principal_id, uniqueness: { scope: :issue_id, message: 'already has access to this issue' }

  # Ensure principal exists as a valid User or Group
  validates :principal_id, inclusion: { in: -> { valid_principal_ids },
                                         message: 'must be a valid user or group' }, allow_nil: true

  private

  # Get list of valid principal IDs (users and groups in the system)
  def self.valid_principal_ids
    Principal.where(type: ['User', 'Group']).pluck(:id)
  end
end
