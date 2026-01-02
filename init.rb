require 'redmine'

Redmine::Plugin.register :redmine_issue_access_control do
  name 'Redmine Issue Access Control Plugin'
  author 'Antigravity'
  description 'Granular access control for issues based on users and groups.'
  version '0.0.1'
  url 'https://github.com/example/redmine_issue_access_control'
  author_url 'https://github.com/example'

  project_module :issue_access_control do
    permission :set_issue_access_control, {}
    permission :view_all_restricted_issues, {}
  end
end

# Add lib to load path
lib_dir = File.join(File.dirname(__FILE__), 'lib')
$LOAD_PATH.unshift(lib_dir) unless $LOAD_PATH.include?(lib_dir)

def apply_patch
  STDERR.puts "redmine_issue_access_control: Attempting to apply patches..."
  require_dependency 'issue'
  require 'redmine_issue_access_control/patches/issue_patch'
  
  unless Issue.included_modules.include?(RedmineIssueAccessControl::Patches::IssuePatch)
    STDERR.puts "redmine_issue_access_control: Including IssuePatch into Issue"
    Issue.send(:include, RedmineIssueAccessControl::Patches::IssuePatch)
  else
    STDERR.puts "redmine_issue_access_control: IssuePatch already included"
  end
  
  require 'redmine_issue_access_control/hooks/issues_hook_listener'
  STDERR.puts "redmine_issue_access_control: Patches applied successfully"
rescue => e
  STDERR.puts "redmine_issue_access_control: Error applying patches: #{e.message}"
end

# Immediate application if Issue is already loaded (though it might not be)
apply_patch if defined?(Issue)

# Deferred application for when the app is ready and for reloads
Rails.configuration.to_prepare do
  apply_patch
end
