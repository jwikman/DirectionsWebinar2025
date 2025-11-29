# Quick Start: Running BC on Linux POC

This guide helps you quickly test the Linux build workflow.

## Prerequisites

- GitHub repository with GitHub Actions enabled
- The workflow files are already in place (see below)

## Files Added

✅ `.github/workflows/build-linux.yml` - GitHub Actions workflow
✅ `scripts/run-tests-odata.ps1` - PowerShell test execution script
✅ `scripts/README.md` - Script documentation
✅ `docs/linux-build-setup.md` - Detailed setup documentation

## How to Run

### Option 1: Via GitHub Web UI

1. Go to your repository on GitHub
2. Click on the **Actions** tab
3. Select **Build Linux (Full Test)** workflow from the left sidebar
4. Click **Run workflow** button (top right)
5. Select your branch (e.g., `w/johwik/bc-on-linux`)
6. Click the green **Run workflow** button

### Option 2: Via API/CLI

```bash
# Using GitHub CLI
gh workflow run build-linux.yml --ref w/johwik/bc-on-linux

# View workflow runs
gh run list --workflow=build-linux.yml
```

## What Happens

The workflow will:

1. ✅ Install .NET 8.0 and AL compiler
2. ✅ Download BC symbol packages (System, Base, Application)
3. ✅ Compile The Library app
4. ✅ Clone BCDevOnLinux repository
5. ✅ Build BC Wine container
6. ✅ Start BC container (takes ~5-10 minutes)
7. ✅ Publish app to container
8. ⏭️ Test execution (currently skipped - no tests in app)
9. ✅ Upload artifacts with compiled app and metrics

**Expected duration: ~10-20 minutes**

## Monitoring Progress

1. In GitHub Actions, click on the running workflow
2. Click on "Linux Full Test Build" job
3. Watch each step execute in real-time
4. Green checkmarks = success, red X = failure

### Key Steps to Watch

- **Install BC Development Tools for Linux** - Should complete in ~30 seconds
- **Download BC Symbol Packages** - Should complete in ~60 seconds
- **Compile AL Extension** - Should succeed if app.json is valid
- **Start BC Container** - Longest step, wait for "healthy" status
- **Publish AL Extension to Container** - Should succeed if container is healthy

## Expected Results

### Success Indicators

- ✅ Compilation completes without errors
- ✅ Container becomes "healthy"
- ✅ App publishes successfully
- ✅ Artifacts uploaded

### Download Artifacts

1. After workflow completes, scroll to bottom of workflow run page
2. Find **Artifacts** section
3. Download `linux-full-test-artifacts.zip`
4. Extract to find:
   - `Johannes Wikman_The Library_1.0.0.0.app`
   - `linux-full-test-metrics.json`
   - `linux-full-test-raw-measurements.json`

## Troubleshooting

### Workflow Not Appearing

- Make sure files are committed to the repository
- Check `.github/workflows/build-linux.yml` exists
- Refresh GitHub Actions page

### Compilation Fails

Check the "Compile AL Extension" step output:
- Verify symbol packages downloaded
- Check for AL syntax errors
- Confirm app.json dependencies are satisfied

### Container Fails to Start

Check the "Start BC Container" step:
- Look for "healthy" status message
- If timeout occurs, container may need more time
- Check BCDevOnLinux repository is accessible

### Publishing Fails

- Ensure container reached "healthy" status
- Verify app file was created in compilation step
- Check for dependency conflicts

## Testing Locally

You can also test the PowerShell script locally if you have a BC container:

```powershell
# Run against local BC container
.\scripts\run-tests-odata.ps1 `
  -BaseUrl "http://localhost:7048/BC" `
  -CodeunitId 50002
```

**Note:** This requires your app to have test runner infrastructure (see `docs/linux-build-setup.md`).

## Next Steps After POC

If the POC succeeds:

1. ✅ Verify compiled app works
2. ⏭️ Add test codeunits to The Library app
3. ⏭️ Add test runner infrastructure
4. ⏭️ Enable test execution in workflow
5. ⏭️ Convert bash scripts to PowerShell (optional)
6. ⏭️ Set up regular builds on main branch

## Getting Help

- Review detailed documentation: `docs/linux-build-setup.md`
- Check test script docs: `scripts/README.md`
- Source repository: [PipelinePerformanceComparison](https://github.com/StefanMaron/PipelinePerformanceComparison)
- BC on Linux: [BCDevOnLinux](https://github.com/StefanMaron/BCDevOnLinux)

## Bash vs PowerShell Note

The workflow currently uses **bash scripts** as requested for POC. These work fine on Linux runners. When ready, you can convert them to PowerShell for:

- Better error handling
- Cross-platform consistency
- PowerShell's object-oriented features
- Easier maintenance

See `docs/linux-build-setup.md` for conversion examples.

---

**Good luck with the POC! 🚀**
