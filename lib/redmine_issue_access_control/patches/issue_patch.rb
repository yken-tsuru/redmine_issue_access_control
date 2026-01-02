module RedmineIssueAccessControl
  module Patches
    module IssuePatch
      extend ActiveSupport::Concern

      # Constants for permission names and module identifier
      PLUGIN_PERMISSION_UNRESTRICTED = :view_all_restricted_issues
      PLUGIN_MODULE_NAME = :issue_access_control

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
          
          # [1] Admin check: always visible
          return true if user.admin?

          # [2] Standard permission check: apply Redmine standard rules
          return false unless super(user)

          # [3] Module enabled check: if disabled, use standard visibility
          return true unless access_control_enabled?

          # [4] Unrestricted access check: view_all_restricted_issues permission
          return true if user.allowed_to?(PLUGIN_PERMISSION_UNRESTRICTED, project)

          # [5] Access rules check: author, assignee, or explicit whitelist
          check_access_rules(user)
        end

        def editable?(user = User.current)
          return false unless visible?(user)
          super(user)
        end

        private

        def access_control_enabled?
          project&.module_enabled?(PLUGIN_MODULE_NAME) || false
        end

        def check_access_rules(user)
          # Author and assignee always have access
          return true if author_id == user.id || assigned_to_id == user.id

          # Check explicit access rules (user or user's groups)
          allowed_principal_ids = user.group_ids + [user.id]
          issue_access_rules.where(principal_id: allowed_principal_ids).exists?
        end
      end

      module ClassMethodsPatch
        def visible_condition(user, options = {})
          sql = super(user, options)
          return sql if user.admin?

          allowed_principal_ids = user.group_ids + [user.id]
          
          condition = build_visibility_condition(user, allowed_principal_ids)
          safe_condition = Issue.send(:sanitize_sql_for_conditions, condition)
          
          "#{sql} AND (#{safe_condition})"
        end

        private

        def build_visibility_condition(user, allowed_principal_ids)
          table_name = Issue.table_name
          user_id = user.id

          # Build SQL condition that mirrors the Ruby logic in visible?
          condition_sql = <<~SQL
            (NOT EXISTS (SELECT 1 FROM enabled_modules em 
                         WHERE em.project_id = #{table_name}.project_id 
                         AND em.name = 'issue_access_control')
             OR #{build_unrestricted_access_condition(user_id, table_name)}
             OR #{table_name}.author_id = #{user_id}
             OR #{table_name}.assigned_to_id = #{user_id}
             OR #{table_name}.id IN (SELECT iar.issue_id FROM issue_access_rules iar 
                                      WHERE iar.principal_id IN (?)))
          SQL

          [condition_sql, allowed_principal_ids]
        end

        def build_unrestricted_access_condition(user_id, table_name)
          # Check if user has view_all_restricted_issues permission
          "#{table_name}.project_id IN (
            SELECT m.project_id
            FROM members m
            JOIN member_roles mr ON mr.member_id = m.id
            JOIN roles r ON r.id = mr.role_id
            WHERE m.user_id = #{user_id} AND r.permissions LIKE '%:view_all_restricted_issues%'
          )"
        end
      end
    end
  end
end
