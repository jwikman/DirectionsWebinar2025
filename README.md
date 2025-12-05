# The Library

This repository was created for the Directions Webinar: Benefitting from Open Source 2025-11-25

It contains a sample AL project that demonstrates how to use the GitHub Copilot with NAB AL Tools, either locally or with GitHub Copilot Coding Agent in the Cloud.

## Workspace Configuration

You can use the workspace configuration file `The Library.code-workspace` as inspiration for your own workspace configuration.

## Using GitHub Copilot Locally

Copy the following files from this repository to your local AL project (create the folders if they do not exist):

- `.github\agents\BC Translator.agent.md`
- `.github\prompts\Translate-App.prompt.md`

After copying the files, you can start using the GitHub Copilot with
NAB AL Tools locally. Just run the prompt above by writing `/Translate-App` in the Copilot chat in VSCode. You can also add additional instructions after the prompt command, like `/Translate-App please translate to French and German.`

It should find the prompt file, switch to the BC Translator agent, and execute the translation according to instructions.

## Using GitHub Copilot Coding Agent

### Configure Copilot in the Repository settings

Configure the MCP Servers for the Copilot Coding Agent by using the following MCP Configuration in your repository settings on GitHub:

```json
{
  "mcpServers": {
    "nab-al-tools-mcp": {
      "type": "local",
      "command": "npx",
      "args": [
        "-y",
        "@nabsolutions/nab-al-tools-mcp"
      ],
      "tools": [
        "*"
      ]
    },
    "al-test-runner": {
      "type": "local",
      "command": "npx",
      "args": [
        "-y",
        "@al-test-runner/mcp-server"
      ],
      "tools": [
        "*"
      ]
    }
  }
}
```

Add the path to the BaseApp translation files to _Custom allowlist_:
`https://nabaltools.file.core.windows.net/shared/base_app_lang_files`

### Setup files in the repository

Copy the following file from this repository to your repository (create the folders if they do not exist):

- `.github\instructions\translate-xlf.instructions.md`
- `.github\instructions\mcp-servers.instructions.md`
- `.github\workflows\copilot-setup-steps.yml`
- `.github\initialize-coding-agent.ps1`
- `.github\copilot-instructions.md`

### Start using Copilot Coding Agent

After above setup, you can start using the Copilot Coding Agent in your repository by
assigning an issue or a work item to `Copilot` or by mentioning `@copilot` in a comment.

- "@Copilot, please make sure that all texts are translated."
- "@Copilot, please translate this app into French and German."
