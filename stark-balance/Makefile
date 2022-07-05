
balance_compiled.json: balance.cairo
	cairo-compile balance.cairo --output balance_compiled.json

test: balance_compiled.json
	cairo-run --program=balance_compiled.json --print_output --layout=small --program_input=balance_in.json

sharp: balance_compiled.json
	cairo-sharp submit --source balance.cairo --program_input balance_in.json
	date