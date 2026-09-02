#!/bin/sh

# Git's test harness evaluates quoted test bodies and invokes helpers from them.
# shellcheck disable=SC1091,SC2016,SC2034,SC2329

test_description='cx integration with Herdr tab labels'

. ./test-lib.sh

hook="$TEST_DIRECTORY/../.zsh/cx.d/herdr"

run_cx_herdr_hook () {
	HOOK_PATH="$hook" TITLE="$1" zsh -fc '
		run_hook () {
			local full_wtitle=$TITLE
			source "$HOOK_PATH"
		}
		run_hook
	'
}

test_expect_success 'cx prefers HERDR_BIN_PATH when renaming a tab' '
	cat >fake-herdr <<-\EOF &&
	#!/bin/sh
	printf "%s\n" "$@" >"$CAPTURE"
	EOF
	chmod +x fake-herdr &&
	cat >expect <<-\EOF &&
	tab
	rename
	tab-7
	foo title
	EOF
	CAPTURE="$PWD/actual" HERDR_BIN_PATH="$PWD/fake-herdr" \
		HERDR_TAB_ID=tab-7 run_cx_herdr_hook "foo title" &&
	test_cmp expect actual
'

test_expect_success 'cx falls back to herdr on PATH' '
	mkdir fallback-bin &&
	cat >fallback-bin/herdr <<-\EOF &&
	#!/bin/sh
	printf "%s\n" "$@" >"$CAPTURE"
	EOF
	chmod +x fallback-bin/herdr &&
	cat >expect <<-\EOF &&
	tab
	rename
	tab-8
	fallback title
	EOF
	CAPTURE="$PWD/actual" HERDR_BIN_PATH= HERDR_TAB_ID=tab-8 \
		PATH="$PWD/fallback-bin:$PATH" run_cx_herdr_hook "fallback title" &&
	test_cmp expect actual
'

test_expect_success 'cx reports Herdr rename failures' '
	cat >failing-herdr <<-\EOF &&
	#!/bin/sh
	echo "protocol mismatch" >&2
	exit 1
	EOF
	chmod +x failing-herdr &&
	CAPTURE="$PWD/unused" HERDR_BIN_PATH="$PWD/failing-herdr" \
		HERDR_TAB_ID=tab-9 run_cx_herdr_hook "broken title" 2>actual-error &&
	echo "cx: Herdr tab rename failed: protocol mismatch" >expect-error &&
	test_cmp expect-error actual-error
'

test_done
