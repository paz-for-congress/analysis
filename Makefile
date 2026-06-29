.PHONY: data app edit html export encrypt publish serve check

PUBLISH_REMOTE ?= origin
PUBLISH_BRANCH ?= main
PUBLISH_REPO ?= paz-for-congress/analysis
PUBLISH_SOURCE ?= dist/encrypted/campaign_eda.html
PUBLISH_TARGET ?= index.html
PUBLISH_MESSAGE ?= Update encrypted analysis page

data:
	uv run python scripts/build_public_data.py

app:
	uv run marimo run campaign_eda.py --no-sandbox --host $(shell hostname) --watch

edit:
	uv run marimo edit campaign_eda.py --no-sandbox

html:
	mkdir -p dist
	uv run marimo export html campaign_eda.py \
		-o dist/campaign_eda.html --no-include-code -f

export: html
	uv run marimo export html-wasm campaign_eda.py \
		-o dist/wasm --mode run --no-show-code --execute --sandbox -f

encrypt: html
	npx --yes staticrypt@3 dist/campaign_eda.html \
		--directory dist/encrypted \
		--remember false \
		--config false \
		--template-title "The 5th congressional district"

publish: encrypt
	@test -f "$(PUBLISH_SOURCE)" || (echo "Missing $(PUBLISH_SOURCE)"; exit 1)
	cp "$(PUBLISH_SOURCE)" "$(PUBLISH_TARGET)"
	git add -f "$(PUBLISH_TARGET)"
	@set -e; \
	if git diff --cached --quiet -- "$(PUBLISH_TARGET)"; then \
		echo "No encrypted page changes to publish."; \
	else \
		git commit -m "$(PUBLISH_MESSAGE)"; \
		git push "$(PUBLISH_REMOTE)" HEAD:"$(PUBLISH_BRANCH)"; \
		gh api "repos/$(PUBLISH_REPO)/pages/builds" -X POST >/dev/null \
			&& echo "Queued GitHub Pages build." \
			|| echo "Pushed; GitHub Pages should build from the push."; \
		echo "Published https://paz-for-congress.github.io/analysis/"; \
	fi

serve:
	python3 -m http.server 8000 --directory dist/wasm

check:
	uv run marimo check campaign_eda.py
