# MCP Servers Available for the GitHub Coding Agent

This document describes the Model Context Protocol (MCP) servers available for use by the GitHub Coding Agent in this repository, along with their primary use cases and recommendations.

## 1. nab-al-tools-mcp

- **Purpose:** Used for translation workflows and AL localization support.
- **Recommended Usage:**
  - Use for extracting, managing, and synchronizing XLF files and translations.
  - Preferred for automating translation tasks, reviewing translation states, and ensuring localization consistency.

### Available Tools

1. **initialize** (MCP only)
   - Initializes the MCP server with the AL app folder path and optional workspace file path
   - Must be called before any other tool
   - Locates the generated XLF file (.g.xlf) in the Translations folder
   - Loads the app manifest from app.json
   - Configures global settings

2. **getGlossaryTerms**
   - Returns glossary terminology pairs for a target language
   - Based on Business Central terminology and translations
   - Outputs JSON array of objects with 'source', 'target', and 'description'

3. **refreshXlf**
   - Refreshes and synchronizes an XLF file using the generated XLF file
   - Preserves existing translations while adding new translation units
   - Maintains the state of translated units and sorts the file

4. **getTextsToTranslate**
   - Retrieves untranslated texts from a specified XLF file
   - Returns translation objects with id, source text, source language, context, maxLength, and comments
   - Supports pagination with offset and limit parameters

5. **getTranslatedTextsMap**
   - Retrieves previously translated texts from a specified XLF file as a translation map
   - Groups all translations by their source text
   - Useful for maintaining translation consistency

6. **getTranslatedTextsByState**
   - Retrieves translated texts filtered by their translation state
   - States include: 'needs-review', 'translated', 'final', 'signed-off'
   - Returns objects with id, source text, target text, context, and state information

7. **saveTranslatedTexts**
   - Writes translated texts to a specified XLF file
   - Accepts an array of translation objects with unique identifiers
   - Enables efficient updating of XLF files with new or revised translations

8. **createLanguageXlf**
   - Creates a new XLF file for a specified target language
   - Based on the generated XLF file from the initialized app
   - Optionally prepopulated with matching translations from Microsoft's base application

9. **getTextsByKeyword**
   - Searches source or target texts in an XLF file for a given keyword or regex
   - Returns matching translation units
   - Useful for discovering how specific words or phrases are used across the application

---

## 2. github-mcp-server

- **Purpose:** Provides GitHub API integration for repository operations, issue management, pull requests, workflows, and code scanning.
- **Recommended Usage:**
  - Use for interacting with GitHub repositories, issues, pull requests, and workflows
  - Preferred for code search, commit history analysis, and CI/CD workflow management

### Available Tools

1. **search_code**
   - Fast and precise code search across GitHub repositories
   - Supports exact matching, language filters, path filters, and advanced search syntax

2. **search_repositories**
   - Find GitHub repositories by name, description, readme, topics, or metadata
   - Supports sorting by stars, forks, help-wanted-issues, or updated date

3. **search_issues**
   - Search for issues in GitHub repositories using issues search syntax
   - Supports sorting by comments, reactions, interactions, created, or updated date

4. **search_pull_requests**
   - Search for pull requests in GitHub repositories
   - Supports filtering by state, author, and various sort options

5. **search_users**
   - Find GitHub users by username, real name, or profile information
   - Supports sorting by followers, repositories, or join date

6. **get_file_contents**
   - Get the contents of a file or directory from a GitHub repository
   - Supports specific refs like branches, tags, or commit SHAs

7. **list_commits**
   - Get list of commits from a branch in a GitHub repository
   - Supports filtering by author and pagination

8. **get_commit**
   - Get details for a specific commit including diffs and stats
   - Supports pagination for large commits

9. **list_branches**
   - List branches in a GitHub repository
   - Supports pagination

10. **list_tags**
    - List git tags in a GitHub repository
    - Supports pagination

11. **get_tag**
    - Get details about a specific git tag

12. **list_pull_requests**
    - List pull requests in a GitHub repository
    - Supports filtering by state, base branch, head branch, and sorting

13. **pull_request_read**
    - Get information on a specific pull request
    - Methods: get, get_diff, get_status, get_files, get_review_comments, get_reviews, get_comments

14. **list_issues**
    - List issues in a GitHub repository
    - Supports filtering by state, labels, and sorting

15. **issue_read**
    - Get information about a specific issue
    - Methods: get, get_comments, get_sub_issues, get_labels

16. **list_issue_types**
    - List supported issue types for repository owner (organization)

17. **get_label**
    - Get a specific label from a repository

18. **list_releases**
    - List releases in a GitHub repository

19. **get_latest_release**
    - Get the latest release in a GitHub repository

20. **get_release_by_tag**
    - Get a specific release by its tag name

21. **list_workflows**
    - List workflows in a repository

22. **list_workflow_runs**
    - List workflow runs for a specific workflow
    - Supports filtering by actor, branch, event, and status

23. **get_workflow_run**
    - Get details of a specific workflow run

24. **get_workflow_run_usage**
    - Get usage metrics for a workflow run

25. **list_workflow_jobs**
    - List jobs for a specific workflow run

26. **get_job_logs**
    - Download logs for a specific workflow job or all failed job logs for a run

27. **get_workflow_run_logs**
    - Download logs for a specific workflow run (downloads ALL logs as ZIP)

28. **summarize_job_log_failures**
    - Retrieve and summarize failed GitHub Actions job logs for a workflow run

29. **summarize_run_log_failures**
    - Analyze and explain why a GitHub Actions workflow run failed

30. **list_workflow_run_artifacts**
    - List artifacts for a workflow run

31. **download_workflow_run_artifact**
    - Get download URL for a workflow run artifact

32. **list_code_scanning_alerts**
    - List code scanning alerts in a GitHub repository
    - Supports filtering by state, severity, and tool name

33. **get_code_scanning_alert**
    - Get details of a specific code scanning alert

34. **list_secret_scanning_alerts**
    - List secret scanning alerts in a GitHub repository
    - Supports filtering by state and resolution

35. **get_secret_scanning_alert**
    - Get details of a specific secret scanning alert

36. **web_search**
    - AI-powered web search for current, factual information with citations

---

## 3. playwright

- **Purpose:** Provides browser automation capabilities for web testing and interaction.
- **Recommended Usage:**
  - Use for UI testing, web scraping, and automated browser interactions
  - Preferred for taking screenshots, filling forms, and navigating web pages

### Available Tools

1. **browser_navigate**
   - Navigate to a URL

2. **browser_navigate_back**
   - Go back to the previous page

3. **browser_snapshot**
   - Capture accessibility snapshot of the current page (better than screenshot for actions)

4. **browser_take_screenshot**
   - Take a screenshot of the current page or a specific element
   - Supports full page screenshots and different image formats

5. **browser_click**
   - Perform click on a web page element
   - Supports left, right, middle button and double-click

6. **browser_hover**
   - Hover over an element on the page

7. **browser_type**
   - Type text into an editable element
   - Supports slow typing and submit after typing

8. **browser_press_key**
   - Press a key on the keyboard

9. **browser_fill_form**
   - Fill multiple form fields at once
   - Supports textbox, checkbox, radio, combobox, and slider fields

10. **browser_select_option**
    - Select an option in a dropdown

11. **browser_file_upload**
    - Upload one or multiple files

12. **browser_drag**
    - Perform drag and drop between two elements

13. **browser_evaluate**
    - Evaluate JavaScript expression on page or element

14. **browser_handle_dialog**
    - Handle a dialog (accept/dismiss with optional prompt text)

15. **browser_console_messages**
    - Returns all console messages

16. **browser_network_requests**
    - Returns all network requests since loading the page

17. **browser_tabs**
    - List, create, close, or select a browser tab

18. **browser_wait_for**
    - Wait for text to appear/disappear or a specified time to pass

19. **browser_resize**
    - Resize the browser window

20. **browser_close**
    - Close the page

21. **browser_install**
    - Install the browser specified in the config

---

**Note:** Select the appropriate MCP server based on the task at hand:
- For translation and localization, use **nab-al-tools-mcp**
- For GitHub repository operations, use **github-mcp-server**
- For browser automation and UI testing, use **playwright**
