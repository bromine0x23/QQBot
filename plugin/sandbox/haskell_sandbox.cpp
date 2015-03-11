#if !(defined(__linux__) && defined(__x86_64__))
#error "Unsupported platform type"
#endif /**/

#ifndef PROG_NAME
#define PROG_NAME "haskell_sandbox"
#endif /* PROG_NAME */

#include <cassert>
#include <cerrno>
#include <climits>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#include <utility>

#include <fcntl.h>
#include <syscall.h>
#include <sysexits.h>
#include <unistd.h>
#include <sys/ptrace.h>

#include <sandbox.h>

using Rule = void (*)(sandbox_t const *, event_t const *, action_t *);

void policy_entry(policy_t const * policy, event_t const * event, action_t* action);

struct Sandbox {
	sandbox_t sandbox;
	policy_t default_policy;

	Sandbox(int argc, const char * argv[]) {
		if (sandbox_init(&sandbox, argv + 1) != 0) {
			fprintf(stderr, "sandbox initialization failed\n");
			exit(EX_DATAERR);
		}

		sandbox.task.quota[S_QUOTA_WALLCLOCK] = 5000; // 9s
		sandbox.task.quota[S_QUOTA_CPU]       = 4000; // 8s
		sandbox.task.quota[S_QUOTA_MEMORY]    = 64 << 20; // 64MB
		sandbox.task.quota[S_QUOTA_DISK]      = 1 << 20; // 1MB

		setup_policy();
	}

	~Sandbox() {
		sandbox_fini(&sandbox);
	}

	result_t execute() {
		if (!sandbox_check(&sandbox)) {
			fprintf(stderr, "sandbox pre-execution state check failed\n");
			exit(EX_DATAERR);
		}
		return *sandbox_execute(&sandbox);
	}

private:

	void setup_policy() {
		default_policy = sandbox.ctrl.policy;
		if (!default_policy.entry) {
			default_policy.entry = reinterpret_cast< void * >(sandbox_default_policy);
		}
		sandbox.ctrl.policy = policy_t{
			reinterpret_cast< void * >(policy_entry),
			reinterpret_cast< long >(this)
		};
	}
};

void policy_entry(policy_t const * policy, event_t const * event, action_t* action) {
	assert(policy && event && action);

	auto sandbox = (Sandbox const *)(policy->data);

	switch (event->type) {
	case S_EVENT_SYSCALL: {
		*action = action_t{S_ACTION_CONT};
		return;
	}
	case S_EVENT_ERROR:
	case S_EVENT_EXIT:
	case S_EVENT_SIGNAL:
	case S_EVENT_SYSRET:
	case S_EVENT_QUOTA:
	default:
		break;
	}

	((policy_entry_t)sandbox->default_policy.entry)(&sandbox->default_policy, event, action);
}

int main(int argc, const char * argv[]) {
	if (argc < 2) {
		fprintf(stderr, "synopsis: " PROG_NAME " foo/bar.exe\n");
		return EX_USAGE;
	}

	switch (Sandbox(argc, argv).execute()) {
	case S_RESULT_OK:
		return 0;
	case S_RESULT_RF:
		return 1;
	case S_RESULT_ML:
		return 2;
	case S_RESULT_OL:
		return 3;
	case S_RESULT_TL:
		return 4;
	case S_RESULT_RT:
		return 5;
	default:
		return -1;
	}
	return -1;
}