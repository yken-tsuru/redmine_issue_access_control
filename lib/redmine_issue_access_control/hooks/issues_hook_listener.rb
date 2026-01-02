module RedmineIssueAccessControl
  module Hooks
    class IssuesHookListener < Redmine::Hook::ViewListener
      # Permission names (must match init.rb definitions)
      PERMISSION_SET_ACCESS_CONTROL = :set_issue_access_control
      MODULE_NAME = :issue_access_control

      # Hook: Render access control form in the issue edit view
      # Displays the access control selection UI only for users with permission
      def view_issues_form_details_bottom(context = {})
        return unless user_can_set_access_control?(context)
        
        render_partial(context, 'issue_access_control/form')
      end

      # Hook: Display allowed members in the issue detail view
      # Shows the list of users/groups who can access this issue
      def view_issues_show_details_bottom(context = {})
        return unless module_enabled?(context)
        
        render_partial(context, 'issue_access_control/show_access_list')
      end

      # Hook: Save access rules when a new issue is created
      def controller_issues_new_after_save(context = {})
        save_access_rules(context)
      end

      # Hook: Save access rules when an issue is edited
      def controller_issues_edit_after_save(context = {})
        save_access_rules(context)
      end

      private

      # Render a partial with safe error handling
      def render_partial(context, partial_name)
        context[:controller].send(:render_to_string, {
          partial: partial_name,
          locals: context
        })
      rescue => e
        Rails.logger.error("Error rendering partial #{partial_name}: #{e.message}")
        nil
      end

      # Check if current user can set access control rules
      def user_can_set_access_control?(context)
        project = context[:project]
        return false unless project

        User.current.allowed_to?(PERMISSION_SET_ACCESS_CONTROL, project)
      end

      # Check if the module is enabled for the project
      def module_enabled?(context)
        project = context[:project]
        return false unless project

        project.module_enabled?(MODULE_NAME)
      end

      # Save access rules from form submission
      # Clears existing rules and creates new ones from submitted principal_ids
      def save_access_rules(context)
        issue = context[:issue]
        params = context[:params]

        # Return if no access control data was submitted
        return unless params[:issue_access_control].present?

        # Verify user has permission to modify access rules
        return unless user_can_set_access_control?(project: issue.project)

        # Atomically update access rules
        update_issue_access_rules(issue, params[:issue_access_control])
      rescue => e
        Rails.logger.error("Error saving access rules for issue #{issue.id}: #{e.message}")
      end

      # Update access rules for an issue
      # Replaces all existing rules with the new set of principals
      def update_issue_access_rules(issue, access_control_params)
        principal_ids = extract_principal_ids(access_control_params)

        # Use transaction to ensure atomicity
        ActiveRecord::Base.transaction do
          issue.issue_access_rules.destroy_all
          
          principal_ids.each do |principal_id|
            issue.issue_access_rules.create!(principal_id: principal_id)
          end
        end
      end

      # Extract and validate principal IDs from access control parameters
      def extract_principal_ids(access_control_params)
        principal_ids = access_control_params[:principal_ids]
        
        return [] unless principal_ids.is_a?(Array)
        
        principal_ids.reject(&:blank?).map(&:to_i)
      end
    end
  end
end
