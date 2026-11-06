extends RefCounted
## Version and build time shown when the game starts (and in the F1 help).
## The web build workflow overwrites this file before exporting
## (.github/workflows/web.yml); these are the values when running from the
## editor.

const VERSION := "dev"
const BUILD_DATE := ""
const COMMIT := ""


## E.g. "v0.1.47 · 6.11.2026 09:44", or "dev" when run from the editor.
static func text() -> String:
	if BUILD_DATE == "":
		return VERSION
	return "v%s · %s" % [VERSION, BUILD_DATE]
