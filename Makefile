.PHONY: doc lint test check build site status help

doc:
	Rscript dev/dev_agent.R doc

lint:
	Rscript dev/dev_agent.R lint

test:
	Rscript dev/dev_agent.R test

check:
	Rscript dev/dev_agent.R check

build:
	Rscript dev/dev_agent.R build

site:
	Rscript dev/dev_agent.R site

status:
	Rscript dev/dev_agent.R status

help:
	Rscript dev/dev_agent.R help
