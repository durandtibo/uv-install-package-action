#!/usr/bin/env bats
#
# Tests of dev/check_bats_assertions.sh, which rejects the bats assertions that
# pass vacuously on bash 3.2.

setup() {
	CHECK="$BATS_TEST_DIRNAME/../../dev/check_bats_assertions.sh"
	DIR="$BATS_TEST_TMPDIR/check_dir"
	mkdir -p "$DIR"
}

# Writes a .bats file with the given body lines in a test
write_test() {
	printf '%s\n' '@test "t" {' "$@" '}' >"$DIR/t.bats"
}

@test "check_bats_assertions accepts the tests of the repository" {
	run "$CHECK" "$BATS_TEST_DIRNAME"

	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "check_bats_assertions rejects a [[ ]] assertion without || false" {
	write_test '  [[ "$output" =~ "x" ]]' '  true'

	run "$CHECK" "$DIR"

	[ "$status" -eq 1 ]
	[[ "$output" == *"t.bats:2:"* ]] || false
}

@test "check_bats_assertions rejects a negated [[ ]] assertion without || false" {
	write_test '  [[ ! "$output" =~ "x" ]]'

	run "$CHECK" "$DIR"

	[ "$status" -eq 1 ]
}

@test "check_bats_assertions rejects a negated command" {
	write_test '  ! grep -q x file' '  true'

	run "$CHECK" "$DIR"

	[ "$status" -eq 1 ]
}

@test "check_bats_assertions rejects an indented assertion" {
	write_test '      [[ "$a" == "$b" ]]'

	run "$CHECK" "$DIR"

	[ "$status" -eq 1 ]
}

@test "check_bats_assertions accepts a [[ ]] assertion with || false" {
	write_test '  [[ "$output" =~ "x" ]] || false'

	run "$CHECK" "$DIR"

	[ "$status" -eq 0 ]
}

@test "check_bats_assertions accepts a negated command with || false" {
	write_test '  ! grep -q x file || false'

	run "$CHECK" "$DIR"

	[ "$status" -eq 0 ]
}

@test "check_bats_assertions accepts single bracket assertions" {
	write_test '  [ "$status" -eq 0 ]' '  [ -z "$output" ]'

	run "$CHECK" "$DIR"

	[ "$status" -eq 0 ]
}

@test "check_bats_assertions accepts a [[ ]] used as a condition" {
	write_test '  if [[ "$output" == x ]]; then' '    true' '  fi'

	run "$CHECK" "$DIR"

	[ "$status" -eq 0 ]
}

@test "check_bats_assertions fails with status 2 for a missing directory" {
	run "$CHECK" "$DIR/does_not_exist"

	[ "$status" -eq 2 ]
}

@test "check_bats_assertions accepts an empty directory" {
	run "$CHECK" "$DIR"

	[ "$status" -eq 0 ]
}
