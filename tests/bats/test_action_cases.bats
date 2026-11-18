#!/usr/bin/env bats
# The cases of the action tests (levels 2 and 3) are data: tests/action_cases.json. These tests
# check that the table is well formed and covers every input of action.yaml.

setup() {
	BATS_TEST_DIRNAME="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
	CASES="${BATS_TEST_DIRNAME}/../action_cases.json"
	ACTION="${BATS_TEST_DIRNAME}/../../action.yaml"
}

@test "the file is a JSON array with unique ids" {
	run jq -e 'type == "array" and length > 0 and (map(.id) | length == (unique | length))' "$CASES"
	[ "$status" -eq 0 ]
}

@test "every case has an id, inputs, an expectation and a released flag" {
	run jq -e 'all(.[]; (.id | type == "string") and (.inputs | type == "object")
    and (.expect == "success" or .expect == "failure") and (.released | type == "boolean"))' "$CASES"
	[ "$status" -eq 0 ]
}

@test "every input named by a case exists in action.yaml" {
	local input
	for input in $(jq -r '[.[].inputs | keys[]] | unique[]' "$CASES"); do
		grep -q "^  ${input}:" "$ACTION" || {
			echo "unknown input: $input" >&2
			false
		}
	done
}

@test "every input of action.yaml has a case that sets it" {
	local input
	for input in $(awk '/^inputs:/{f=1;next} /^[a-z]/{f=0} f && /^  [a-z-]+:/{sub(":","",$1); print $1}' "$ACTION"); do
		jq -e --arg i "$input" 'any(.[]; .inputs | has($i))' "$CASES" >/dev/null || {
			echo "no case sets $input" >&2
			false
		}
	done
}

@test "every validated input has a case with an invalid value that fails" {
	local input
	for input in package-name package-version python-version invalid-version-mode; do
		jq -e --arg i "$input" 'any(.[]; .expect == "failure" and (.inputs | has($i)))' "$CASES" >/dev/null || {
			echo "no failing case sets $input" >&2
			false
		}
	done
}

@test "a success case expects the outputs of a valid run: valid and installed go together" {
	run jq -e 'all(.[] | select(.expect == "success"); (.valid == "true" and .installed == "true" and has("version-prefix"))
    or (.valid == "false" and .installed == "false" and (has("version-prefix") | not)))' "$CASES"
	[ "$status" -eq 0 ]
}

@test "a success case runs with the released action, as the positive control of the released failure cases" {
	run jq -e 'any(.[]; .expect == "success" and .released == true)' "$CASES"
	[ "$status" -eq 0 ]
}
