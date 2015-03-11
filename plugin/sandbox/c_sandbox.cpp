#if !(defined(__linux__) && defined(__x86_64__))
#error "Unsupported platform type"
#endif /**/

#ifndef PROG_NAME
#define PROG_NAME "c_sandbox"
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
	Rule rules[1 << 10];

	Sandbox(int argc, const char * argv[]) {
		if (sandbox_init(&sandbox, argv + 1) != 0) {
			fprintf(stderr, "sandbox initialization failed\n");
			exit(EX_DATAERR);
		}

		sandbox.task.quota[S_QUOTA_WALLCLOCK] = 3000; // 3s
		sandbox.task.quota[S_QUOTA_CPU]       = 2000; // 2s
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
		static auto const SAFE_SYSCALL = {
			SYS_arch_prctl,
			SYS_brk,
			SYS_clock_gettime,
			SYS_close,
			SYS_exit_group,
			SYS_fstat,
			SYS_mmap,
			SYS_mprotect,
			SYS_munmap,
			SYS_read,
			SYS_times,
			SYS_write,
		};

		static auto const kill_rf = [](sandbox_t const * sandbox, event_t const * event, action_t * action) {
			*action = action_t{S_ACTION_KILL, {{S_RESULT_RF}}};
		};

		static auto const kill_rt = [](sandbox_t const * sandbox, event_t const * event, action_t * action) {
			*action = action_t{S_ACTION_KILL, {{S_RESULT_RT}}};
		};

		static auto const cont = [](sandbox_t const * sandbox, event_t const * event, action_t * action) {
			*action = action_t{S_ACTION_CONT};
		};

		static auto const get_str = [](sandbox_t const * sandbox, long addr, char * str, unsigned int length) {
			union {
				unsigned long data;
				char bytes[sizeof(unsigned long)];
			} word;

			char buffer[0x1000];
			sprintf(buffer, "/proc/%d/mem", sandbox->ctrl.pid);

			if (access(buffer, R_OK | F_OK) < 0) {
				fprintf(stderr, "procfs entries missing or invalid\n");
				return false;
			}

			int fd = open(buffer, O_RDONLY);

			if (lseek(fd, (off_t)addr, SEEK_SET) < 0) {
				fprintf(stderr, "lseek(%d, %ld, SEEK_SET) failes, ERRNO %d\n", fd, addr, errno);
				return false;
			}

			char * output = str;
			for (bool eol = false ;!eol; ) {
				if (read(fd, static_cast< void * >(&word), sizeof(long)) < 0) {
					fprintf(stderr, "read\n");
					return false;
				}
				for (auto i = 0U; !eol && i < sizeof(long);) {
					eol = ((*output++ = word.bytes[i++]) == '\0');
				}
			}

			close(fd);

			return true;
		};

		static auto const access_rule = [](sandbox_t const * sandbox, event_t const * event, action_t * action) {
			static auto const valid_arguments = {
				std::make_pair("/etc/ld.so.nohwcap", F_OK),
				std::make_pair("/etc/ld.so.preload", R_OK),
			};
			auto addr = event->data._SYSCALL.a;
			auto mode = event->data._SYSCALL.b;
			char filename[PATH_MAX + 1];
			if (get_str(sandbox, addr, filename, PATH_MAX + 1)) {
				for (auto const & argument : valid_arguments) {
					if ((strcmp(filename, argument.first) == 0) && (mode == argument.second)) {
						return cont(sandbox, event, action);
					}
				}
				return kill_rf(sandbox, event, action);
			}
			return kill_rt(sandbox, event, action);
		};

		static auto const open_rule = [](sandbox_t const * sandbox, event_t const * event, action_t * action) {
			static auto const valid_arguments = {
				std::make_pair("/etc/ld.so.cache",                         (O_RDONLY | O_CLOEXEC)),
				std::make_pair("/etc/localtime",                           (O_RDONLY | O_CLOEXEC)),
				std::make_pair("/lib/x86_64-linux-gnu/libc.so.6",          (O_RDONLY | O_CLOEXEC)),
			};
			auto addr = event->data._SYSCALL.a;
			auto flag = event->data._SYSCALL.b;
			char filename[PATH_MAX + 1];
			if (get_str(sandbox, addr, filename, PATH_MAX + 1)) {
				for (auto const & argument : valid_arguments) {
					if ((strcmp(filename, argument.first) == 0) && (flag & argument.second)) {
						return cont(sandbox, event, action);
					}
				}
				return kill_rf(sandbox, event, action);
			}
			return kill_rt(sandbox, event, action);
		};

		for (auto & rule : rules) {
			rule = kill_rf;
		}

		for (auto const & syscall : SAFE_SYSCALL) {
			rules[syscall] = cont;
		}

		rules[SYS_access] = access_rule;
		rules[SYS_open] = open_rule;

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
		auto scinfo = event->data._SYSCALL.scinfo;
		using SCInfo = decltype(scinfo);
		union {
			syscall_t syscall;
			SCInfo scinfo;
		} u;
		u.scinfo = scinfo;
		sandbox->rules[u.syscall.scno](&sandbox->sandbox, event, action);
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