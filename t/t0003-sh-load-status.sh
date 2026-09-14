#!/bin/sh

# Git's test harness evaluates quoted test bodies and invokes helpers from them.
# shellcheck disable=SC1091,SC2016,SC2034,SC2329

test_description='sh_load_status logging'

. ./test-lib.sh

shared_env="$TEST_DIRECTORY/../.shared_env"

run_shared_env () {
	shell_under_test=$1
	shift
	SHARED_ENV="$shared_env" HOME="$PWD/home" DEBUG_LOCAL_HOOKS=0 \
		"$shell_under_test" "$@" -fc '
		eval "$(sed -n '\''/^sh_load_status () {/,/^}/p'\'' "$SHARED_ENV")" &&
		sh_load_status .shared_env
		' 2>"actual-error-$shell_under_test"
}

run_in_both_shells () {
	for shell_under_test in bash zsh; do
		run_shared_env "$shell_under_test" "$@" || return
	done
}

run_writability_transition () {
	shell_under_test=$1
	SHARED_ENV="$shared_env" HOME="$PWD/home" DEBUG_LOCAL_HOOKS=0 \
		"$shell_under_test" -fc '
		eval "$(sed -n '\''/^sh_load_status () {/,/^}/p'\'' "$SHARED_ENV")" &&
		real_home=$HOME &&
		sh_load_status first &&
		sleep 0.05 &&
		HOME=/sys sh_load_status skipped &&
		sleep 0.05 &&
		HOME=$real_home sh_load_status resumed
		' 2>"actual-transition-error-$shell_under_test"
}

if test "$(id -u)" != 0; then
	test_set_prereq NOT_ROOT
fi
if test -w /dev/full; then
	test_set_prereq DEV_FULL
fi
if test -d /sys && test ! -w /sys; then
	test_set_prereq READ_ONLY_SYS
fi

test_expect_success 'sh_load_status creates its log directory and logs' '
	mkdir -p home &&
	for shell_under_test in bash zsh; do
		rm -rf home/.log &&
		run_shared_env "$shell_under_test" &&
		grep -F ".shared_env" home/.log/sh_load_status.log || return
	done
'

test_expect_success NOT_ROOT 'sh_load_status skips an unwritable log file' '
	mkdir -p home/.log &&
	: >home/.log/sh_load_status.log &&
	chmod a-w home/.log home/.log/sh_load_status.log &&
	run_in_both_shells &&
	chmod u+w home/.log home/.log/sh_load_status.log &&
	for shell_under_test in bash zsh; do
		test_must_fail grep -F "sh_load_status.log" \
			"actual-error-$shell_under_test" || return
	done &&
	test ! -s home/.log/sh_load_status.log
'

test_expect_success READ_ONLY_SYS 'logging resumes without stale elapsed time' '
	for shell_under_test in bash zsh; do
		rm -rf home/.log &&
		run_writability_transition "$shell_under_test" &&
		grep -F "(   0ms later)  resumed" \
			home/.log/sh_load_status.log || return
	done
'

test_expect_success DEV_FULL 'a late log write failure does not trigger errexit' '
	rm -rf home/.log &&
	mkdir -p home/.log &&
	ln -s /dev/full home/.log/sh_load_status.log &&
	run_in_both_shells -e &&
	for shell_under_test in bash zsh; do
		test ! -s "actual-error-$shell_under_test" || return
	done
'

test_done
