#!/usr/bin/env bats
# action.yaml and README.md must describe the same inputs and outputs, and action.yaml must pass
# the inputs to the scripts the way CLAUDE.md requires. Nothing else checks it: a renamed input, a
# changed default or an output documented but not exposed would pass every other test.
#
# The files are parsed with awk (no YAML library is needed). The helpers read the files from
# ACTION_FILE and README_FILE so that the last tests can run them on modified copies.

setup() {
	BATS_TEST_DIRNAME="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
	ACTION_FILE="${BATS_TEST_DIRNAME}/../../action.yaml"
	README_FILE="${BATS_TEST_DIRNAME}/../../README.md"
	COPY_DIR="$(mktemp -d)"
}

teardown() {
	rm -rf "$COPY_DIR"
}

# --------------------------------------------------------
# Helpers
# --------------------------------------------------------

# The names of the inputs of action.yaml, one per line
action_inputs() {
	awk '/^inputs:/ {f=1; next} /^[a-z]+:/ {f=0} f && /^  [a-z-]+:$/ {gsub(/[: ]/, ""); print}' "$ACTION_FILE"
}

# The names of the outputs of action.yaml, one per line
action_outputs() {
	awk '/^outputs:/ {f=1; next} /^[a-z]+:/ {f=0} f && /^  [a-z-]+:$/ {gsub(/[: ]/, ""); print}' "$ACTION_FILE"
}

# The value of a field of an input of action.yaml, without quotes (a "" gives an empty string)
# Args: $1 - input name, $2 - field (default or required)
action_field() {
	awk -v name="$1" -v field="$2" '
    /^inputs:/ {f=1; next}
    /^[a-z]+:/ {f=0}
    f && /^  [a-z-]+:$/ {gsub(/[: ]/, ""); cur=$0; next}
    f && cur == name && $0 ~ "^    " field ":" {sub("^    " field ": *", ""); print; exit}
  ' "$ACTION_FILE" | sed -E 's/^"(.*)"$/\1/'
}

# The rows of the table of a section of the README
# Args: $1 - last word of the "## " heading ("Inputs" or "Outputs")
readme_rows() {
	awk -v title="$1" '
    /^## / {f = ($NF == title); next}
    f && /^\| `/ {print}
  ' "$README_FILE"
}

# The names documented in the README, one per line
# Args: $1 - section title
readme_names() {
	readme_rows "$1" | awk -F'|' '{gsub(/[ `]/, "", $2); print $2}'
}

# The "Required" column of the README for an input: "true" for Yes, "false" for No
# Args: $1 - input name
readme_required() {
	readme_rows Inputs | awk -F'|' -v name="$1" '
    {n = $2; gsub(/[ `]/, "", n)}
    n == name {r = $3; gsub(/ /, "", r); print (r == "Yes" ? "true" : "false"); exit}
  '
}

# The default of an input in the README, without the backticks, only when it is a code span
# (the README writes a text such as "auto-detected" when the default is computed)
# Args: $1 - input name
readme_default() {
	readme_rows Inputs | awk -F'|' -v name="$1" '
    {n = $2; gsub(/[ `]/, "", n)}
    n == name {
      d = $4; gsub(/^ +| +$/, "", d)
      if (d ~ /^`[^`]*`$/) {gsub(/`/, "", d); gsub(/^"|"$/, "", d); print d}
      exit
    }
  '
}

# The names present in the first list and not in the second one
# Args: $1, $2 - lists of names, one per line
only_in_first() {
	comm -23 <(echo "$1" | sort) <(echo "$2" | sort)
}

# Copies action.yaml and README.md to a temporary directory and uses the copies
use_copies() {
	cp "$ACTION_FILE" "$COPY_DIR/action.yaml"
	cp "$README_FILE" "$COPY_DIR/README.md"
	ACTION_FILE="$COPY_DIR/action.yaml"
	README_FILE="$COPY_DIR/README.md"
}

# --------------------------------------------------------
# Inputs
# --------------------------------------------------------

@test "sync: action.yaml has inputs" {
	[ "$(action_inputs | wc -l | tr -d ' ')" -ge 5 ]
}

@test "sync: every input of action.yaml is documented in the README" {
	missing=$(only_in_first "$(action_inputs)" "$(readme_names Inputs)")

	[ -z "$missing" ] || {
		echo "not in the README: $missing" >&2
		false
	}
}

@test "sync: every input of the README exists in action.yaml" {
	stale=$(only_in_first "$(readme_names Inputs)" "$(action_inputs)")

	[ -z "$stale" ] || {
		echo "not in action.yaml: $stale" >&2
		false
	}
}

@test "sync: every input of action.yaml has a description" {
	local name
	for name in $(action_inputs); do
		[ -n "$(action_field "$name" description)" ] || {
			echo "no description for $name" >&2
			false
		}
	done
}

@test "sync: the required flag of every input is the same in action.yaml and in the README" {
	local name
	for name in $(action_inputs); do
		[ "$(action_field "$name" required)" = "$(readme_required "$name")" ] || {
			echo "required of $name: action.yaml='$(action_field "$name" required)' README='$(readme_required "$name")'" >&2
			false
		}
	done
}

@test "sync: the default of an optional input is the same in action.yaml and in the README" {
	local name documented
	for name in $(action_inputs); do
		[ "$(action_field "$name" required)" = "false" ] || continue
		documented=$(readme_default "$name")
		# a README default that is a text ("auto-detected") is not a value to compare
		[ -n "$documented" ] || [ -z "$(action_field "$name" default)" ] || continue
		[ "$(action_field "$name" default)" = "$documented" ] || {
			echo "default of $name: action.yaml='$(action_field "$name" default)' README='$documented'" >&2
			false
		}
	done
}

# --------------------------------------------------------
# Outputs
# --------------------------------------------------------

@test "sync: action.yaml has outputs" {
	[ "$(action_outputs | wc -l | tr -d ' ')" -ge 3 ]
}

@test "sync: every output of action.yaml is documented in the README" {
	missing=$(only_in_first "$(action_outputs)" "$(readme_names Outputs)")

	[ -z "$missing" ] || {
		echo "not in the README: $missing" >&2
		false
	}
}

@test "sync: every output of the README exists in action.yaml" {
	stale=$(only_in_first "$(readme_names Outputs)" "$(action_outputs)")

	[ -z "$stale" ] || {
		echo "not in action.yaml: $stale" >&2
		false
	}
}

# --------------------------------------------------------
# Passing the inputs to the scripts
# --------------------------------------------------------

@test "sync: every input is passed through env, never interpolated in a run: block" {
	local name
	for name in $(action_inputs); do
		grep -qE "^        [A-Z_]+: \\$\{\{ inputs\\.$name \}\}$" "$ACTION_FILE" || {
			echo "input $name is not passed in an env: block" >&2
			false
		}
	done
}

@test "sync: no input is used outside an env: block" {
	# every use of inputs.* is the value of an env variable
	bad=$(grep -F "\${{ inputs." "$ACTION_FILE" | grep -vE '^        [A-Z_]+: \$\{\{ inputs\.[a-z-]+ \}\}$' | grep -vE '^    (value|description):' || true)

	[ -z "$bad" ] || {
		echo "input used outside env: $bad" >&2
		false
	}
}

@test "sync: every run: step of action.yaml sets shell: bash and starts with set -euo pipefail" {
	runs=$(grep -cE '^      run:' "$ACTION_FILE")
	shells=$(grep -cE '^      shell: bash$' "$ACTION_FILE")
	strict=$(grep -cE '^        set -euo pipefail$' "$ACTION_FILE")

	[ "$runs" -ge 1 ]
	[ "$runs" -eq "$shells" ]
	[ "$runs" -eq "$strict" ]
}

# --------------------------------------------------------
# The helpers detect a drift (tests of the checks themselves)
# --------------------------------------------------------

@test "sync helpers: an input removed from the README is reported" {
	use_copies
	grep -v "^| \`uv-args\`" "$README_FILE" >"$README_FILE.new" && mv "$README_FILE.new" "$README_FILE"

	[ "$(only_in_first "$(action_inputs)" "$(readme_names Inputs)")" = "uv-args" ]
}

@test "sync helpers: an input renamed in action.yaml is reported on both sides" {
	use_copies
	sed -i.bak 's/^  uv-args:$/  uvargs:/' "$ACTION_FILE"

	[ "$(only_in_first "$(action_inputs)" "$(readme_names Inputs)")" = "uvargs" ]
	[ "$(only_in_first "$(readme_names Inputs)" "$(action_inputs)")" = "uv-args" ]
}

@test "sync helpers: a changed default is reported" {
	use_copies
	sed -i.bak 's/^    default: "skip"$/    default: "fail"/' "$ACTION_FILE"

	[ "$(action_field invalid-version-mode default)" = "fail" ]
	[ "$(readme_default invalid-version-mode)" = "skip" ]
}

@test "sync helpers: a default written as text in the README is not read as a value" {
	[ -z "$(readme_default python-version)" ]
}

@test "sync helpers: an empty string default is read as empty on both sides" {
	[ -z "$(action_field uv-args default)" ]
	[ "$(readme_default uv-args)" = '' ] || [ "$(readme_default uv-args)" = '""' ]
}

@test "sync helpers: an output removed from the README is reported" {
	use_copies
	grep -v "^| \`installed-version\`" "$README_FILE" >"$README_FILE.new" && mv "$README_FILE.new" "$README_FILE"

	[ "$(only_in_first "$(action_outputs)" "$(readme_names Outputs)")" = "installed-version" ]
}

@test "sync helpers: a changed required flag is reported" {
	use_copies
	sed -i.bak '/^  package-version:$/,/^  python-version:$/ s/^    required: true$/    required: false/' "$ACTION_FILE"

	[ "$(action_field package-version required)" = "false" ]
	[ "$(readme_required package-version)" = "true" ]
}
