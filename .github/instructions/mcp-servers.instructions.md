# MCP Servers Available for the GitHub Coding Agent

This document describes the Model Context Protocol (MCP) servers available for use by the GitHub Coding Agent in this repository, along with their primary use cases and recommendations.

## 1. nab-al-tools-mcp
- **Purpose:** Used for translation workflows and AL localization support.
- **Recommended Usage:**
  - Use for extracting, managing, and synchronizing XLF files and translations.
  - Preferred for automating translation tasks, reviewing translation states, and ensuring localization consistency.

## 2. al-test-runner
- **Purpose:** Used for discovering and running AL tests in Business Central projects.
- **Recommended Usage:**
  - Use for discovering test codeunits and test methods in AL workspaces
  - Use for executing AL tests against Business Central containers
  - Use for retrieving test configuration from .altestrunner.json and app.json
  - Preferred for automating test execution and validating AL code changes
- **Available Tools:**
  - `discover_al_tests`: Scans AL workspace for test codeunits and methods
  - `run_al_tests`: Executes tests in Business Central and returns results
  - `get_test_configuration`: Retrieves AL Test Runner configuration and settings
- **Prerequisites:**
  - TestApp folder with app.json containing test dependencies (Library Assert, Test Runner, Any, Library Variable Storage)
  - .altestrunner.json configuration file (optional, can provide credentials as parameters)
  - Running Business Central Docker container for test execution

---

**Note:** Select the appropriate MCP server based on the task at hand. For translation and localization, use nab-al-tools-mcp. For test discovery and execution, use al-test-runner.
