#!/usr/bin/env bats

load helpers

# $1: parent directory (contains temp-dir-* and lock-* for tempdir.RecoverStaleDirs)
# Sets: staledir, lockpath, mountpath
inject_stale_tempdir() {
	local base=$1
	mkdir -p "${base}"
	staledir=${base}/temp-dir-999999999
	lockpath=${base}/lock-999999999
	mountpath=${staledir}/1-deadbeefdeadbeefdeadbeef/merged
	mkdir -p "${mountpath}"
	touch "${lockpath}"
}

function teardown() {
	mount | awk -v t="${TESTDIR}" 'index($3, t) == 1 { print $3 }' | xargs -r umount 2>/dev/null || true
	basic_teardown
}

@test "recover stale tempdir with mount" {
	case "$STORAGE_DRIVER" in
	overlay)
		;;
	*)
		skip "only overlay calls MakePrivate"
		;;
	esac

	run storage --debug=false create-layer
	[ "$status" -eq 0 ]
	[ "$output" != "" ]

	# Undo the MakePrivate bind mount left by the previous command.
	# This simulates failure of the previous storage invocation: the next
	# storage invocation will redo the mount and create a new submount.
	umount ${TESTDIR}/root/overlay

	local base=${TESTDIR}/root/${STORAGE_DRIVER}/tempdirs
	inject_stale_tempdir "${base}"
	mount -t tmpfs tmpfs "${mountpath}"
	mount | grep -q "${mountpath}"

	run storage --debug=false layers
	echo "$output"
	[ "$status" -eq 0 ]

	run test -d ${staledir}
	[ "$status" -ne 0 ]

	run test -f ${lockpath}
	[ "$status" -ne 0 ]
}

@test "recover stale tempdir without mount" {
	run storage --debug=false create-layer
	[ "$status" -eq 0 ]
	[ "$output" != "" ]

	local base=${TESTDIR}/root/${STORAGE_DRIVER}-layers/tmp
	inject_stale_tempdir "${base}"

	run storage --debug=false layers
	echo "$output"
	[ "$status" -eq 0 ]

	run test -d ${staledir}
	[ "$status" -ne 0 ]

	run test -f ${lockpath}
	[ "$status" -ne 0 ]
}
