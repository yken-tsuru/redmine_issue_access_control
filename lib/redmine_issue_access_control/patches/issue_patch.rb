module RedmineIssueAccessControl
  module Patches
    module IssuePatch
      extend ActiveSupport::Concern

      included do
        Rails.logger.info "RedmineIssueAccessControl: Including IssuePatch into Issue"
        has_many :issue_access_rules, dependent: :destroy
        has_many :allowed_principals, through: :issue_access_rules, source: :principal
        
        # Prepend the overrides module to ensure super() works correctly
        prepend InstanceMethods
        singleton_class.prepend ClassMethodsPatch
      end
      
      module InstanceMethods
        def visible?(user = nil)
          user ||= User.current
          # Admin check
          return true if user.admin?

          # Standard check
          return false unless super(user)

          # Check if module is enabled for the project
          return true unless project&.module_enabled?(:issue_access_control)

          # Check for unrestricted access permission
          return true if user.allowed_to?(:view_all_restricted_issues, project)

          # Access rules check
          # Author and Assignee should always see it
          return true if author_id == user.id || assigned_to_id == user.id

          allowed_ids = user.group_ids + [user.id]
          return true if issue_access_rules.where(principal_id: allowed_ids).exists?
          return false
        end

        def editable?(user = User.current)
          return false unless visible?(user)
          super(user)
        end
      end

      module ClassMethodsPatch
        def visible_condition(user, options = {})
          sql = super(user, options)
          return sql if user.admin?

          allowed_principal_ids = user.group_ids + [user.id]
          table_name = Issue.table_name
          user_id = user.id
          
          condition = <<~SQL
            (NOT EXISTS (SELECT 1 FROM enabled_modules em WHERE em.project_id = #{table_name}.project_id AND em.name = 'issue_access_control')
             OR (
               #{table_name}.project_id IN (
                 SELECT m.project_id
                 FROM members m
                 JOIN member_roles mr ON mr.member_id = m.id
                 JOIN roles r ON r.id = mr.role_id
                 WHERE m.user_id = #{user_id} AND r.permissions LIKE '%:view_all_restricted_issues%'
               )
             )
             OR #{table_name}.author_id = #{user_id}
             OR #{table_name}.assigned_to_id = #{user_id}
             OR #{table_name}.id IN (SELECT iar.issue_id FROM issue_access_rules iar WHERE iar.principal_id IN (?)))
          SQL
          
          safe_condition = Issue.send(:sanitize_sql_for_conditions, [condition, allowed_principal_ids])
          
          "(#{sql}) AND (#{safe_condition})"
        end
      end
    end
  end
end
