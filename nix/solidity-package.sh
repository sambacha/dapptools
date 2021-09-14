source $stdenv/setup
unpackPhase

dir="$out/dapp/$name"
opts=(--combined-json=abi,bin,bin-runtime,srcmap,srcmap-runtime,ast,metadata --overwrite)

mkdir -p "$dir"
cd "$dir"

cp -r "$src" src

mkdir -p lib
source <(echo "$LIBSCRIPT")

mkdir -p out
mapfile -t files < <(find "$dir/src" -name '*.sol')
json_file="out/dapp.sol.json"
(
	set -x
	solc $REMAPPINGS "${opts[@]}" $solcFlags "${files[@]}" >"$json_file"
)

if [[ "$doCheck" == 1 ]] && command -v dapp2-test-hevm >/dev/null 2>&1; then
	DAPP_OUT=out dapp2-test-hevm
fi

if [[ $flatten == 1 && ! $x =~ \.t(\.[a-z0-9]+)*\.sol$ ]]; then
	flat_file="$DAPP_OUT/$dir/${x##*/}.flat"
	(
		set -x
		solc $REMAPPINGS --allow-paths $DAPP_SRC $solcFlags $jsonopts "$x" >"$json_file"
	)
	(
		set -x
		hevm flatten --source-file "$x" --json-file "$json_file" >"$flat_file"
	)
	x="$flat_file"
fi

if [ "$extract" == 1 ]; then
	mapfile -t contracts < <(jq <"$json_file" '.contracts|keys[]' -r | sort -u -t: -k2 | sort)
	data=$(jq <"$json_file" '.contracts' -r)
	total=${#contracts[@]}
	echo "Extracting build data... [Total: $total]"
	for path in "${contracts[@]}"; do
		fileName="${path#*:}"
		contract=$(echo "$data" | jq '.["'"$path"'"]')
		echo "$contract" | jq '.["abi"]' -r >"out/$fileName.abi"
		echo "$contract" | jq '.["bin"]' -r >"out/$fileName.bin"
		echo "$contract" | jq '.["bin-runtime"]' -r >"out/$fileName.bin-runtime"
		echo "$contract" | jq '.["metadata"]' -r >"out/$fileName.metadata"
	done
fi
