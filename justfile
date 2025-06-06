CRATE_VERSION := `grep '^version' Cargo.toml | head -n 1 | sed 's/version = "\(.*\)"/\1/'`

build-image:
	docker build . -t localhost:5432/ecu_engine:{{CRATE_VERSION}} --network=host

publish-image:
	docker image push localhost:5432/ecu_engine:{{CRATE_VERSION}}