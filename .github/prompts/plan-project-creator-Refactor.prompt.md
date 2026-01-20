## Plan: Refactor project-creator skill to eliminate duplication

Remove duplicated code between scripts and templates by creating a single-source-of-truth template system in `assets/`, making scripts thin orchestrators that reference shared templates.

### Steps

1. **Create `assets/templates/` directory** with individual template files for each component: `ServiceDefaults.csproj`, `Extensions.cs`, `Api.csproj`, `Program.cs`, `WeatherForecast.cs`, `WeatherService.cs`, `WeatherEndpoints.cs`, `DaprStateStore.cs`, `AppHost.cs`, React files (`package.json`, `vite.config.ts`, `store.ts`, components, etc.)

2. **Refactor scripts to be thin orchestrators** in [scripts/](scripts/) — remove all embedded heredocs/template content; scripts should read from `assets/templates/` and only contain shell-specific logic for directory creation, file copying, and placeholder replacement.

3. **Remove `TEMPLATE_API.md` and `TEMPLATE_WEB.md`** from [references/](references/) — these duplicate the templates and scripts; the manual workflow should reference the same `assets/templates/` files.

4. **Refactor [REFERENCE.md](references/REFERENCE.md)** to contain only workflow guidance and architecture decisions — remove all embedded code blocks that duplicate templates; link to `assets/templates/` for actual code.

5. **Update [SKILL.md](SKILL.md)** to document the new structure — clarify that templates live in `assets/`, scripts orchestrate them, and both manual/automated workflows use the same source.

### Further Considerations

1. **Template variable syntax**: Should templates use `{{VAR}}`, `__VAR__`, or `${VAR}` for placeholders? Recommend `{{PROJECT_NAME}}` for clarity and easy sed/PowerShell replacement.

2. **Cross-platform script consolidation**: Keep separate `.sh`/`.ps1` files (minimal orchestration logic) or create a single script with cross-platform runner? Recommend keeping separate but minimal (~50-80 lines each vs current 500+).

3. **Manual workflow documentation**: Should manual workflow reference individual template files or should we create a single `assets/MANUAL_WORKFLOW.md` that imports/concatenates templates? Recommend direct file references for maintainability.
