# Migrations (golang-migrate)

Create: `migrate create -ext sql -dir migrations -seq <name>`
Run all: `migrate -path migrations -database "$DATABASE_URL" up`
Rollback one: `migrate -path migrations -database "$DATABASE_URL" down 1`
Force version: `migrate -path migrations -database "$DATABASE_URL" force <version>`
Install: `go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest`
