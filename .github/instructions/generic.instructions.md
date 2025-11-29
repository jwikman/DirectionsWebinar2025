---
applyTo: '**'
---

# Generic Instructions

## Information Gathering

### Never Assume
- Always ask clarifying questions when information is missing or unclear
- Do not proceed with assumptions without user confirmation
- Request specific details rather than inferring requirements

### Documentation Reading
When given documentation to review:
- **Local files**: Read completely, including all referenced files and nested content
- **Online documentation** (using `fetch` tool): Read main page and up to 2 levels of subpages
- Understand the documentation fully before taking action

## Tool Usage

### Error Handling and Recovery
When a tool call returns an error or unexpected response:
- **Analyze the error message** - Read the full response carefully
- **Follow provided instructions** - Error messages often contain specific guidance on how to resolve the issue
- **Take corrective action** - Adjust parameters, call prerequisite tools, or try alternative approaches
- **Do not repeat failed calls** - If a tool call fails, understand why before retrying

**Common scenarios:**
- Missing prerequisites: Call required tools first (e.g., set context before querying)
- Invalid parameters: Adjust parameter values based on error guidance
- Tool limitations: Use alternative tools or approaches
- Dependency issues: Resolve dependencies before proceeding

**Example:**
```
Error: "Workspace context not set. Call mcp_bc-code-intel_set_workspace_info first."
Action: Call set_workspace_info with the app source path, then retry original query
```

## File Operations

### Explicit Authorization Required
- Do not update, create, or delete files unless explicitly instructed
- Ask for confirmation when the instruction is ambiguous
- Verify scope of changes before proceeding

### Meta-File Updates
When updating instruction files (`.instructions.md`), prompt files (`.prompt.md`), or agent files (`.agent.md`):
- Make changes with appropriate priority relative to existing content
- Use normal formatting (avoid excessive emphasis like "CRITICAL", "MUST NOT", "IMPORTANT")
- Make targeted updates rather than reformatting the entire file
- Match the tone and style of the existing file content

### Markdown Formatting
When creating or editing markdown files, follow common markdown best practices and formatting standards to avoid linter warnings

**Placeholder Conventions:**
- Use `< >` for placeholders (e.g., `<Title>`, `<YYYY-MM-DD>`, `<Description>`)
- Use `[ ]` only for proper markdown links (e.g., `[Link Text](https://example.com)`)
- This avoids confusion between placeholders and actual markdown link syntax

## Communication

### Question Format
When presenting ANY questions to users (not just options):
1. **Always provide numbered alternatives** - This applies to clarification questions, option selection, and requirements gathering
2. Place the recommended option as **number 1** with justification
3. Include 3-5 relevant alternatives when applicable
4. Use bold for question headers to separate multiple questions clearly
5. Use open-ended questions ONLY when alternatives cannot be determined without additional context

**Formatting Example - Option Selection:**
```
How many story points should this user story have?
1. 1 point - Very simple, well-understood change (Recommended - single page update with clear requirements)
2. 2 points - Simple feature with clear requirements
3. 3 points - Moderate complexity, some unknowns
4. 5 points - Complex feature, multiple components
5. 8 points - Large feature, significant unknowns

Please select 1-5, or provide your own assessment.
```

**Formatting Example - Clarification Questions:**
```
**What does "reconciliation" refer to in your system?**
1. A single reconciliation record/document (Recommended - most common interpretation)
2. Multiple reconciliations selected by the user
3. A reconciliation batch or group
4. Other (please specify)

**What are the "files" that need to be included?**
1. Attachments already linked to the reconciliation record (Recommended - standard BC pattern)
2. Supporting documents from separate storage
3. Generated files during process
4. Other (please specify)

Please select the numbered option that best fits, or provide your own answer for each question.
```

### Iterative Approach
When gathering requirements or clarifying details:
1. Ask when information is unclear
2. Present numbered alternatives when multiple options exist
3. Validate understanding by summarizing back to user
4. Ask one question at a time for complex topics
5. Confirm before proceeding with assumptions
