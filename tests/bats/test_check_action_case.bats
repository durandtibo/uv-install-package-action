#!/usr/bin/env bats
# Unit tests for dev/check_action_case.sh, which asserts the result of one run of the action in
# the action tests (ci-action-deps.yaml, ci-action-edge-cases.yaml; local and released action).

setup() {
	BATS_TEST_DIRNAME="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
	CHECK="${BATS_TEST_DIRNAME}/../../dev/check_action_case.sh"
	export CASE='{"id":"c","expect":"success"}'
	export OUTCOME=success
	export VALID=true INSTALLED=true INSTALLED_VERSION=2.4.1 USE_RELEASED=false
}

# fails_with TEXT: the check fails (exit 1) and reports TEXT as an ::error::
fails_with() {
	run "$CHECK"
	[ "$status" -eq 1 ]
	[[ "$output" == *"::error::[c] "*"$1"* ]] || {
		echo "$output" >&2
		false
	}
}

@test "an installed package with well formed outputs passes" {
	run "$CHECK"
	[ "$status" -eq 0 ]
	[[ "$output" == *"Case c"* ]]
}

@test "a skipped installation with well formed outputs passes" {
	VALID=false INSTALLED=false INSTALLED_VERSION="" run "$CHECK"
	[ "$status" -eq 0 ]
}

@test "the outcome must be the expected one" {
	OUTCOME=failure fails_with "outcome: expected 'success', got 'failure'"
}

@test "a missing outcome fails" {
	unset OUTCOME
	fails_with "outcome: expected 'success', got ''"
}

@test "the outcome of a case without expect is success" {
	CASE='{"id":"c"}' run "$CHECK"
	[ "$status" -eq 0 ]
}

@test "is-valid-version must be true or false" {
	local value
	for value in "" True 1 yes; do
		VALID="$value" INSTALLED="$value" fails_with "is-valid-version must be 'true' or 'false'"
	done
}

@test "installed must equal is-valid-version" {
	INSTALLED=false INSTALLED_VERSION="" fails_with "installed (must equal is-valid-version): expected 'true', got 'false'"
}

@test "installed-version must be set when the package was installed" {
	INSTALLED_VERSION="" fails_with "installed-version is empty although the package was installed"
}

@test "installed-version must be empty when the installation was skipped" {
	VALID=false INSTALLED=false INSTALLED_VERSION=2.4.1 fails_with "installed-version must be empty when the installation was skipped"
}

@test "the released action is only checked on is-valid-version" {
	USE_RELEASED=true INSTALLED="" INSTALLED_VERSION="" run "$CHECK"
	[ "$status" -eq 0 ]
	USE_RELEASED=true VALID="" INSTALLED="" INSTALLED_VERSION="" fails_with "is-valid-version must be 'true' or 'false'"
}

@test "an expected is-valid-version is asserted" {
	CASE='{"id":"c","valid":"false"}' fails_with "is-valid-version: expected 'false', got 'true'"
	CASE='{"id":"c","valid":"true"}' run "$CHECK"
	[ "$status" -eq 0 ]
}

@test "an expected installed is asserted" {
	CASE='{"id":"c","installed":"false"}' fails_with "installed: expected 'false', got 'true'"
}

@test "an expected installed is not asserted for the released action" {
	CASE='{"id":"c","installed":"false"}' USE_RELEASED=true INSTALLED="" INSTALLED_VERSION="" run "$CHECK"
	[ "$status" -eq 0 ]
}

@test "an expected version prefix is asserted" {
	CASE='{"id":"c","version-prefix":"2.4."}' run "$CHECK"
	[ "$status" -eq 0 ]
	CASE='{"id":"c","version-prefix":"2.5."}' fails_with "installed-version prefix: expected '2.5.', got '2.4.'"
}

@test "an expected version prefix longer than the version fails" {
	CASE='{"id":"c","version-prefix":"2.4.10"}' fails_with "installed-version prefix"
}

@test "a failure case expects the failure" {
	local case_json='{"id":"c","expect":"failure"}'
	CASE="$case_json" OUTCOME=failure VALID="" INSTALLED="" INSTALLED_VERSION="" run "$CHECK"
	[ "$status" -eq 0 ]
	CASE="$case_json" OUTCOME=success fails_with "outcome: expected 'failure', got 'success'"
}

@test "a failure case can assert the outputs of the validation" {
	local case_json='{"id":"c","expect":"failure","valid":"false","installed":"false"}'
	CASE="$case_json" OUTCOME=failure VALID=false INSTALLED=false INSTALLED_VERSION="" run "$CHECK"
	[ "$status" -eq 0 ]
	CASE="$case_json" OUTCOME=failure VALID=true INSTALLED=false INSTALLED_VERSION="" fails_with "is-valid-version: expected 'false', got 'true'"
}

@test "every problem is reported" {
	CASE='{"id":"c","valid":"false","installed":"false"}' run "$CHECK"
	[ "$status" -eq 1 ]
	[[ "$output" == *"is-valid-version: expected"* && "$output" == *"installed: expected"* ]]
}

@test "CASE is required" {
	unset CASE
	run "$CHECK"
	[ "$status" -ne 0 ]
}
