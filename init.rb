require 'redmine'

# Plugin identifier and constants
REDMINE_ISSUE_ACCESS_CONTROL_PLUGIN_ID = :redmine_issue_access_control
REDMINE_ISSUE_ACCESS_CONTROL_MODULE = :issue_access_control
REDMINE_ISSUE_ACCESS_CONTROL_PERMISSION_SET = :set_issue_access_control
REDMINE_ISSUE_ACCESS_CONTROL_PERMISSION_VIEW_ALL = :view_all_restricted_issues

Redmine::Plugin.register REDMINE_ISSUE_ACCESS_CONTROL_PLUGIN_ID do
  name 'Redmine Issue Access Control Plugin'
  author 'Antigravity'
  description 'Granular access control for issues based on users and groups.'
  version '0.0.1'
  url 'https://github.com/yken-tsuru/redmine_issue_access_controll'
  author_url 'https://github.com/yken-tsuru'
  
  # Redmine 4.0+ is required
  requires_redmine version_or_higher: '4.0.0'

  project_module REDMINE_ISSUE_ACCESS_CONTROL_MODULE do
    permission REDMINE_ISSUE_ACCESS_CONTROL_PERMISSION_SET, {}
    permission REDMINE_ISSUE_ACCESS_CONTROL_PERMISSION_VIEW_ALL, {}
  end
end

# Add lib to load path
lib_dir = File.join(File.dirname(__FILE__), 'lib')
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)

# Patch application logic
def apply_plugin_patches
  STDERR.puts "redmine_issue_access_control: Attempting to apply patches..."
  
  # Load and apply Issue model patch
  load_and_apply_issue_patch
  
  # Load hook listener
  load_hook_listener
  
  STDERR.puts "redmine_issue_access_control: Patches applied successfully"
rescue => e
  STDERR.puts "redmine_issue_access_control: Error applying patches: #{e.message}"
  STDERR.puts e.backtrace.join("\n")
end

# Load and apply the Issue model patch
def load_and_apply_issue_patch
  require_dependency 'issue'
  require 'redmine_issue_access_control/patches/issue_patch'
  
  unless Issue.included_modules.include?(RedmineIssueAccessControl::Patches::IssuePatch)
    STDERR.puts "redmine_issue_access_control: Including IssuePatch into Issue"
    Issue.send(:include, RedmineIssueAccessControl::Patches::IssuePatch)
  else
    STDERR.puts "redmine_issue_access_control: IssuePatch already included"
  end
end

# Load the hook listener
def load_hook_listener
  require 'redmine_issue_access_control/hooks/issues_hook_listener'
end

# Immediate application if Issue is already loaded (though it might not be)
apply_plugin_patches if defined?(Issue)

# Deferred application for when the app is ready and for reloads
Rails.configuration.to_prepare do
  apply_plugin_patches
end
