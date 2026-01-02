/**
 * Issue Access Control Plugin - Client-side behavior
 * Handles search filtering and UI interactions for access control selection
 * Compatible with Redmine 4+
 */

(function() {
  'use strict';

  // Create namespace
  const IssueAccessControl = {
    /**
     * Initialize search filtering for principal selection
     * @param {string} searchInputId - ID of the search input element
     * @param {string} containerInputId - ID of the container with principals to filter
     */
    initializeSearch(searchInputId, containerInputId) {
      const searchInput = document.getElementById(searchInputId);
      const container = document.getElementById(containerInputId);

      if (!searchInput || !container) {
        console.warn('IssueAccessControl: Required elements not found (search input or container)');
        return;
      }

      // Attach keyup event listener for filtering
      searchInput.addEventListener('keyup', (event) => {
        this.filterPrincipals(event.target.value.toLowerCase(), container);
      });
    },

    /**
     * Filter principal labels based on search term
     * Hides/shows labels matching the search term
     * @param {string} searchTerm - The search term to filter by (case-insensitive)
     * @param {HTMLElement} container - The container element with principal labels
     */
    filterPrincipals(searchTerm, container) {
      const labels = container.querySelectorAll('label.issue-access-control-label');

      labels.forEach((label) => {
        const principalName = label.getAttribute('data-name') || '';
        
        // Show label if search term is empty or matches principal name
        const isMatch = searchTerm === '' || principalName.includes(searchTerm);
        label.style.display = isMatch ? 'block' : 'none';
      });
    }
  };

  // Expose to global scope
  window.IssueAccessControl = IssueAccessControl;

  // Auto-initialize when form is present
  document.addEventListener('DOMContentLoaded', () => {
    const searchInput = document.getElementById('issue_access_control_search');
    if (searchInput) {
      IssueAccessControl.initializeSearch('issue_access_control_search', 'issue_access_control_inputs');
    }
  });
})();

