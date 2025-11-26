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

**Note:** Select the appropriate MCP server based on the task at hand. For translation and localization, use nab-al-tools-mcp.
