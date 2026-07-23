#!/usr/bin/env sh

case "$(uname -s)" in
	Darwin)
		memory_pressure -Q 2>/dev/null |
			awk '/System-wide memory free percentage/ { print 100 - $5 "%" }'
		;;
	Linux)
		awk '
			/MemTotal/ { total = $2 }
			/MemAvailable/ { available = $2 }
			END {
				if (total > 0)
					printf "%.0f%%", (total - available) * 100 / total
			}
		' /proc/meminfo
		;;
esac
