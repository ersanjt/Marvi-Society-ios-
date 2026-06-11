.PHONY: status verify sync health db github rollback release hooks

status:
	@bash scripts/release/status.sh

verify:
	@bash scripts/release/verify.sh

sync:
	@bash scripts/release/full-sync.sh

health:
	@bash scripts/check-health.sh

db:
	@bash scripts/release/sync-database.sh

github:
	@bash scripts/release/sync-github.sh

rollback:
	@bash scripts/release/rollback.sh $(filter-out $@,$(MAKECMDGOALS))

release:
	@bash scripts/release/record-release.sh $(filter-out $@,$(MAKECMDGOALS))

hooks:
	@bash scripts/setup-githooks.sh

%:
	@:
