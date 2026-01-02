module RedmineIssueAccessControl
  module Hooks
    class IssuesHookListener < Redmine::Hook::ViewListener
      # Render the access control selection in the issue form
      # Render the access control selection in the issue form
      def view_issues_form_details_bottom(context = {})
        return unless User.current.allowed_to?(:set_issue_access_control, context[:project])
        context[:controller].send(:render_to_string, {
          partial: 'issue_access_control/form',
          locals: context
        })
      end

      def view_issues_show_details_bottom(context = {})
        return unless context[:project].module_enabled?(:issue_access_control)
        
        context[:controller].send(:render_to_string, {
          partial: 'issue_access_control/show_access_list',
          locals: context
        })
      end
      
      # Save the rules after issue is saved
      def controller_issues_new_after_save(context = {})
        save_access_rules(context)
      end

      def controller_issues_edit_after_save(context = {})
        save_access_rules(context)
      end

      private

      def save_access_rules(context)
        issue = context[:issue]
        params = context[:params]
        
        return unless params[:issue_access_control]
        
        # Only users with permission can set these
        return unless User.current.allowed_to?(:set_issue_access_control, issue.project)

        # Clear existing rules
        issue.issue_access_rules.destroy_all
        
        principal_ids = params[:issue_access_control][:principal_ids]
        if principal_ids.is_a?(Array)
          principal_ids.reject(&:blank?).each do |pid|
            issue.issue_access_rules.create(principal_id: pid)
          end
        end
      end
    end
  end
end
